output "alb_sg_id" { value = aws_security_group.alb.id }
output "ecs_tasks_sg_id" { value = aws_security_group.ecs_tasks.id }
output "ecs_execution_role_arn" { value = aws_iam_role.ecs_task_execution_role.arn }
output "ecs_task_role_arn" { value = aws_iam_role.ecs_task_role.arn }