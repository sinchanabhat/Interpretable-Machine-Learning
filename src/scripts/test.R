## Install missing packages and import
dependencies_list <- c("evoxploit", "tidyverse", "checkmate", "rlist","hash", "hms", "ggplot2", "visdat","naniar","xlsx", "pre", "caret", "R6","shinydashboard", "DescTools", "groupdata2")
missing_packages_list <- dependencies_list[!(dependencies_list %in% installed.packages()[,"Package"])]
if(length(missing_packages_list)) install.packages(missing_packages_list)

library(evoxploit)
library(tidyverse)
library(checkmate)
library(rlist)
library(hash)
library(hms)
library(ggplot2)
library(visdat)
library(naniar)
library(pre)
library(caret)
library(R6)
library(xlsx)
library(DescTools)
library(shinydashboard)
library(groupdata2)
source('./scripts/extract-features.R')
source('./scripts/factor-timestamp.R')
source('./scripts/data-with-labels.R')
source('./scripts/grouping-dataframes.R')
source('./scripts/rule-fit-implementation.R')
source('./scripts/ShipCohortStudy.R')
source('./scripts/data_imputation.R')
source('./scripts/data-sampling.R')
## Take sample of ship_data dataset
sample_df <- ship_dataset

#impute_mean(as.vector(sample_df$age_ship_s1))
## Removing data without labels
sample_df <- data_with_labels(sample_df)

## Extraction of labels
sample_labels <- only_labels(data_df = sample_df)
sample_df$liver_fat <- sample_labels

## Extract features present in all 3 waves
sample_df <- extract_features_with_suffix(sample_df, "(_s0|_s1|_s2)")

## Factor Features
sample_df <- factor_timestamp(sample_df, "exdate_ship")
sample_df <- factor_hms(sample_df, "blt_beg")

## Extracting evolution features
evo_extraction_result <- Evoxploit$new(sample_df, sample_labels[[1]], wave_suffix = "_s")
sample_df <- evo_extraction_result$all_features

## Extracting evolution_features for all waves
## After this step, private$..data_df has all original and evo_features available in all waves
sample_df <- extract_features_with_suffix(sample_df, "(_s0|_s1|_s2)")

## Remove gender specific features
group_by_male <- subset(sample_df, female_s0==0)
group_by_female <- subset(sample_df, female_s0==1)
cols_to_remove <- gender_group_compare (group_by_male, group_by_female)
cols_to_remove <- list.append(cols_to_remove, "female_s0")
sample_df <- sample_df[,!names(sample_df) %in% cols_to_remove]

##Remove columns having 5% or more than 5% of missing values(NA)
sample_df <- sample_df[, -which(colMeans(is.na(sample_df)) > 0.05)]

## Impute Data
sample_df <- impute_dataset(sample_df)

## Scaling features for all waves
sample_df <- sample_df%>%
  mutate_at(vars(names(sample_df)[which(sapply(sample_df, is.numeric))])
            ,(function(x) return((x - min(x)) / (max(x) - min(x)))))

sample_df$liver_fat <- sample_labels[[1]]

## Plot Missing Values for wave s0
wave_s0_df <- select(sample_df, ends_with("_s0"))
gg_miss_var(wave_s0_df, show_pct = TRUE)  #shows percentage of missing values in the column
gg_miss_var(wave_s0_df, show_pct = FALSE)  #shows number of missing values in the column
vis_miss(sample_df)  #visualize missing values

## Build Rule Fit Model
ship_study_results <- ShipCohortStudy$new(data_df = sample_df, labels = sample_df$liver_fat, cv_folds = 5)
ship_study_results$summary()

## Validate Model Prediction
validation_set <- ship_study_results$validation_set
actual_labels <- validation_set$liver_fat
validation_set <- validation_set[, !names(validation_set) %in% c("liver_fat")]
model_predictions <- predict(ship_study_results$model, validation_set)
cmp_table <- table(factor(model_predictions, levels = levels(model_predictions)),
                   factor(actual_labels, levels = levels(actual_labels)))
confusionMatrix(cmp_table)

## lower and upper bounds of feature values
print(ship_study_results$model$finalModel$wins_points)

## best tuning parameters
print(ship_study_results$model$finalModel$tuneValue)

## Variable importance
# Coefficients for final linear regression model
imp <- importance(ship_study_results$model$finalModel)
print(imp$varimps)

print(imp$baseimps)



## Exporting to Excel
#output_file_path <- getwd()
#output_file_name <- "sample_df_report.xlsx"
#dataframe_to_write <- sample_df
#write.xlsx(dataframe_to_write, str_c(output_file_path, "/visualization/", output_file_name))