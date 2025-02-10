##
## main.tf
##
terraform {
  required_version = ">= 1.6.3"

  cloud {
    organization = "NorthwellHealth-TFCB"
    workspaces {
      name = "p-d-cds-001"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.35.0"
    }
  }
}

provider "google" {
  project               = var.project_id
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  project               = var.project_id
  user_project_override = true
  billing_project       = var.project_id
}

locals {
  # Map of all roles to bind to the runner Service Account.
  # Role conditions are added as the `value` of the entry.
  # An empty `value` means that no conditions are placed on
  # the permission.
  service_account_roles = [
    "roles/datastore.owner",
    "roles/logging.configWriter",
    "roles/logging.logWriter",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
    "roles/cloudkms.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/compute.viewer",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iam.roleAdmin",
    "roles/pubsub.admin",
    "roles/cloudfunctions.admin",
    "roles/iam.serviceAccountUser",
    "roles/cloudbuild.builds.builder",
    "roles/artifactregistry.admin",
    "roles/container.clusterAdmin",
    "roles/firestore.serviceAgent",
    "roles/discoveryengine.admin",
    "roles/recaptchaenterprise.admin",
    "roles/alloydb.admin",
    "roles/serviceusage.apiKeysAdmin"
  ] 
}

##
## cloud-storage.tf
##
module "test-bucket" {
  source  = "app.terraform.io/NorthwellHealth-TFCB/bucket/gcp"
  version = "0.23.0"

  project_id = var.project_id
  labels     = var.labels
  location   = var.region

  resource_function = "test-bucket"

  use_cmek = false
}

module "test-bucket2" {
  source  = "/NorthwellHealth-TFCB/bucket/gcp"
  version = "0.23.0"

  project_id = var.project_id
  labels     = var.labels
  location   = var.region

  resource_function = "test-bucket"

  use_cmek = false
}

module "test-bucket3" {
  source  = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=26c38a66f12e7c6c93b6a2ba127ad68981a48671"
  version = "0.23.0"

  project_id = var.project_id
  labels     = var.labels
  location   = var.region

  resource_function = "test-bucket"

  use_cmek = false
}

module "test-bucket4" {
  source  = "https://github.com/username/repository?ref=feature-branch"
  version = "0.23.0"

  project_id = var.project_id
  labels     = var.labels
  location   = var.region

  resource_function = "test-bucket"

  use_cmek = false
}

# give members par_GCPAdmin_CDIG_Engineering 
resource "google_project_iam_member" "group_cluster_k8_role" {
  role    = "roles/container.developer"
  member  = "group:${var.security_group}@northwell.edu"
  project = var.project_id
}

# For each of the roles above, attach our runner as a member.
resource "google_project_iam_member" "runner-sa-roles" {
  for_each = toset(local.service_account_roles)

  role    = each.value
  member  = "serviceAccount:${var.tf-service-account}"
  project = var.project_id
}

##
## enabled-apis.tf
##
module "project-services" {
  source  = "app.terraform.io/NorthwellHealth-TFCB/project/gcp//modules/project_services"
  version = "1.1.0"

  project_id = var.project_id

  activate_apis = [
    "logging.googleapis.com",
    "iam.googleapis.com",
    "cloudkms.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "monitoring.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "eventarc.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "container.googleapis.com",
    "firestore.googleapis.com",
    "discoveryengine.googleapis.com",
    "appengine.googleapis.com",
    "datastore.googleapis.com",
    "storage-component.googleapis.com",
    "cloudapis.googleapis.com",
    "servicemanagement.googleapis.com",
    "securetoken.googleapis.com",
    "containersecurity.googleapis.com",
    "recaptchaenterprise.googleapis.com",
    "alloydb.googleapis.com",
    "servicenetworking.googleapis.com",
    "apikeys.googleapis.com"
  ]

  disable_services_on_destroy = false

  depends_on = [google_project_iam_member.runner-sa-roles]
}


#pub sub topic
resource "google_pubsub_topic" "test-topic" {
  name = "test-topic"

  depends_on = [google_project_iam_member.runner-sa-roles]
}

resource "google_service_account" "default" {
  account_id   = "test-gcf-sa"
  display_name = "Test Service Account"
}

## grant iam permissions for publishing messages
resource "google_project_iam_member" "owner_roles" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "group:par_GCPAdmin_CDIG_Engineering@northwell.edu"
}

## grant iam permissions for database users
## we will adjust this to a lower level once we determine what is needed.
## most devs will likely just need roles/alloydb.databaseUser.
## https://cloud.google.com/alloydb/docs/reference/iam-roles-permissions#roles
resource "google_project_iam_member" "database_user_roles" {
  project = var.project_id
  role    = "roles/alloydb.admin"
  member  = "group:par_GCPAdmin_CDIG_Engineering@northwell.edu"
}

## Grant iam permission for recaptcha enterprise admin
resource "google_project_iam_member" "recaptcha_enterprise_enterprise_admin_roles" {
  for_each = toset(var.recaptcha_enterprise_admin_users)

  project = var.project_id
  role    = "roles/recaptchaenterprise.admin"
  member  = "user:${each.value}"
}
