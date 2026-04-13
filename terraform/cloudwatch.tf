resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/${var.project_name}/app"
  retention_in_days = 7

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "nginx_access" {
  name              = "/aws/${var.project_name}/nginx/access"
  retention_in_days = 3

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "nginx_error" {
  name              = "/aws/${var.project_name}/nginx/error"
  retention_in_days = 14

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/aws/${var.project_name}/system"
  retention_in_days = 7

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  alarm_description   = "High CPU utilization on instance"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.project_name}-high-memory"
  alarm_description   = "High memory utilization on instance"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_disk" {
  alarm_name          = "${var.project_name}-high-disk"
  alarm_description   = "High disk utilization on instance"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "instance_health" {
  alarm_name          = "${var.project_name}-instance-health"
  alarm_description   = "EC2 instance failed status check"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = {
    Project = var.project_name
  }
}
