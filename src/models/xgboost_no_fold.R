rm(list = ls())
library(xgboost)
library(dummies)
library(feather)
library(pROC)
setwd('D:/Dropbox/UCDavis/2017spring/DMC_2017_task/github/2017DMC/src')
#setwd('/Users/RayLJazz/Dropbox/UCDavis/2017spring/DMC_2017_task/github/2017DMC/src')

#' load feature matrix and response
train <- read_feather("data/processed/end63_train.feather")
valid <- read_feather("data/processed/end63_test.feather")

train$order <- as.factor(train$order)
train$manufacturer <- as.factor(train$manufacturer)
train$pharmForm <- as.factor(train$pharmForm)
train$group <- as.factor(train$group)
train$unit <- as.factor(train$unit)
train$category <- as.factor(train$category)
train$campaignIndex <- as.factor(train$campaignIndex)
train$salesIndex <- as.factor(train$salesIndex)
train$adFlag <- as.factor(train$adFlag)
train$last_adFlag <- as.factor(train$last_adFlag)
train$availability <- as.factor(train$availability)
train$last_avaibility <- as.factor(train$last_avaibility)
train$group_beginNum <- as.factor(train$group_beginNum)
train$genericProduct <- as.factor(train$genericProduct)
train$content <- as.factor(train$content)
train$avaibility_transition <- as.factor(train$avaibility_transition)
train$adFlag_transition <- as.factor(train$adFlag_transition)



# response and predictors
# Note: may need to update
response <- "order"
predictors <- setdiff(names(train), c("pid", "lineID", "day","order", "basket", "click", "revenue",
                                          "num_items_bought", "weight_qty", "fold_indicator", 
                                          "content_part1", "content_part2", "content_part3",
                                          'pharmForm', 'group','unit',
                                          'category','campaignIndex','salesIndex',
                                          'adFlag','last_adFlag','group_beginNum',
                                          'genericProduct','content','avaibility_transition',
                                          'adFlag_transition','availability','manufacturer',
                                          'last_avaibility','order_qty','fold'
                                          ))
print(predictors)

######create one-hot encoding


Create_One_Hot_Encoding = function(data,variable_name){
  new = dummy(variable_name, sep="_")
  return(cbind(data,new))
}

new=dummy(train$availability, sep="_")
train = cbind(train,new)

# train xgboost model

xgb_grid_1 = expand.grid(
objective = 'binary:logistic',
nrounds = 1000,
eta = c(0.01, 0.001, 0.0001),
max_depth = c(2, 4, 6, 8, 10),
subsample = c(0.2,0.4,0.6,0.8,1), 
colsample_bytree = c(0.2,0.4,0.6,0.8,1)
#gamma = c(0.2,0.4,0.6,0.8,1)
)

X_train = train[,names(train) %in% predictors]
y_train = as.numeric(levels(train$order))[train$order]

X_val = valid[,names(valid) %in% predictors]
y_val =  as.numeric(levels(valid$order))[valid$order]

dtrain <- xgb.DMatrix(as.matrix(X_train), label = y_train)
dval <- xgb.DMatrix(as.matrix(X_val), label = y_val)
watchlist <- list(eval = dval, train = dtrain)

AUC_Hyperparameters <- apply(xgb_grid_1, 1, function(parameterList){

    #Extract Parameters to test
    currentSubsampleRate <- parameterList[["subsample"]]
    currentColsampleRate <- parameterList[["colsample_bytree"]]
    currenteta <- parameterList[["eta"]]
    currentmax_depth <- parameterList[["max_depth"]]

    model_xgb <- xgb.train(param, dtrain, nthread = 40, nrounds = 1e4, watchlist, early.stop.round = 5, maximize = FALSE,
                           "max.depth" = currentmax_depth, "eta" = currenteta,                               
                           "subsample" = currentSubsampleRate, "colsample_bytree" = currentColsampleRate,
                            eval_metric = 'auc')

    train_pred = predict(model_xgb, dval, ntreelimit = model_xgb$bestInd)
    auc_score = auc(y_val,train_pred)

    return(data.frame(auc_score, currentSubsampleRate, currentColsampleRate,currenteta,currentmax_depth, 'n_estimate'=model_xgb$bestInd))

})

AUC_list = do.call(rbind, AUC_Hyperparameters)

head(AUC_list[order(AUC_list$auc_score,decreasing = TRUE),],5)
