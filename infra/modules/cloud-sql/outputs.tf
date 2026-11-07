output "connection_name" {
  description = "project:region:instance, for the Cloud SQL connector in the app."
  value       = google_sql_database_instance.this.connection_name
}

output "database_name" {
  description = "Database created for the app."
  value       = google_sql_database.app.name
}

output "iam_user" {
  description = "Database user name of the runtime identity."
  value       = google_sql_user.runtime.name
}
