terraform {
  backend "gcs" {
    bucket      = ""
    prefix      = ""
    credentials = "umms-hernia-api-dev-7c7f200c2799.json"
  }
}
