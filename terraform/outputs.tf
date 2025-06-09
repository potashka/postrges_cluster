output "pg_master_ip" {
  description = "Внешний IP мастер-сервера"
  value       = yandex_compute_instance.pg_master.network_interface[0].nat_ip_address
}

output "pg_standby_ip" {
  description = "Внешний IP стендбая"
  value       = yandex_compute_instance.pg_standby.network_interface[0].nat_ip_address
}

output "pg_client_ip" {
  description = "Внешний IP клиента"
  value       = yandex_compute_instance.pg_client.network_interface[0].nat_ip_address
}
