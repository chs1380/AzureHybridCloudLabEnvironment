resource "azurerm_application_insights" "func_application_insights" {
  name                = "func-application-insights"
  location            = var.LOCATION
  resource_group_name = var.RESOURCE_GROUP.name
  application_type    = "other"
}

resource "azurerm_app_service_plan" "func_app_service_plan" {
  name                = "func-app-service-plan"
  location            = var.LOCATION
  resource_group_name = var.RESOURCE_GROUP.name
  kind                = "FunctionApp"
  reserved            = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "null_resource" "function_app_build_publish" {
  provisioner "local-exec" {
    working_dir = abspath("${path.module}/${var.FUNCTION_APP_FOLDER}")
    command     = "dotnet publish -p:PublishProfile=FolderProfile"
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(abspath("${path.module}/${var.FUNCTION_APP_FOLDER}"), "*.cs") : filemd5(abspath("${path.module}/${var.FUNCTION_APP_FOLDER}/${f}"))]))
  }
}

data "archive_file" "azure_function_deployment_package" {
  type        = "zip"
  source_dir  = abspath("${path.module}/${var.FUNCTION_APP_PUBLISH_FOLDER}")
  output_path = abspath("${path.module}/${var.FUNCTION_APP_PUBLISH_FOLDER}/../deployment.zip")
  depends_on = [
    null_resource.function_app_build_publish
  ]
}

resource "azurerm_function_app" "func_function_app" {
  name                = "${var.PREFIX}-${var.ENVIRONMENT}-function-app"
  location            = var.LOCATION
  resource_group_name = var.RESOURCE_GROUP.name
  app_service_plan_id = azurerm_app_service_plan.func_app_service_plan.id
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "dotnet",
    AzureWebJobsStorage            = var.STORAGE_CONNECTION_STRING,
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.func_application_insights.instrumentation_key,
    WEBSITE_RUN_FROM_PACKAGE       = "1"
    StorageAccountName             = var.STORAGE_ACC_NAME
    StorageAccountKey              = var.STORAGE_ACC_KEY
    EmailSmtp                      = var.EMAIL_SMTP
    EmailUserName                  = var.EMAIL_USERNAME
    EmailPassword                  = var.EMAIL_PASSWORD
    EmailFromAddress               = var.EMAIL_FROM_ADDRESS
    AdminEmail                     = var.ADMIN_EMAIL
    Salt                           = var.PREFIX
  }
  os_type                    = "linux"
  storage_account_name       = var.STORAGE_ACC_NAME
  storage_account_access_key = var.STORAGE_ACC_KEY
  version                    = "~4"
  identity {
    type = "SystemAssigned"
  }
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"], # prevent TF reporting configuration drift after app code is deployed
    ]
  }
}

data "azurerm_subscription" "primary" {}

locals {
  publish_code_command = "az functionapp deployment source config-zip --resource-group ${var.RESOURCE_GROUP.name} --name ${azurerm_function_app.func_function_app.name} --src ${data.archive_file.azure_function_deployment_package.output_path}"
}

resource "null_resource" "function_app_publish" {
  provisioner "local-exec" {
    command = local.publish_code_command
  }
  depends_on = [
    local.publish_code_command,
    null_resource.function_app_build_publish,
    data.archive_file.azure_function_deployment_package
  ]
  triggers = {
    # source_md5           = filemd5(data.archive_file.azure_function_deployment_package.output_path)
    publish_code_command = local.publish_code_command
    build_number         = "${timestamp()}"
  }
}