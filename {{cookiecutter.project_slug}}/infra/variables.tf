variable "project_slug" {
  type    = string
  default = "{{ cookiecutter.project_slug }}"
}

variable "environment" {
  type    = string
  default = "{{ cookiecutter.environment_name }}"
}