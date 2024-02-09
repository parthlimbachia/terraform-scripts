resource "aws_vpc" "main" {
  cidr_block = var.cidr_range

  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.environment}-Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "${var.environment}-Private Subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-VPC-GW"
  }
}

resource "aws_route_table" "second_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.environment}-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.second_rt.id
}

resource "aws_security_group" "sec_group_alb" {
  name        = "sec_group_alb"
  description = "Security group for Load balancer"
  vpc_id      = aws_vpc.main.id

  # Ingress rule for HTTP (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule for HTTPS (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-sec_group_alb"
  }
}

resource "aws_security_group" "allow_port_5432_from_other_sg" {
  name        = "allow-port-5432-from-other-sg"
  description = "Allow inbound traffic on port 5432 from another security group"
  vpc_id      = aws_vpc.main.id

  # Define inbound rule to allow traffic on port 5432 from another security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sec_group_alb.id]
  }

  # Define outbound rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.environment}-sec_rds_sg"
  }
}

resource "aws_security_group" "allow_port_6379_from_other_sg" {
  name        = "allow-port-6379-from-other-sg"
  description = "Allow inbound traffic on port 6379 from another security group"
  vpc_id      = aws_vpc.main.id

  # Define inbound rule to allow traffic on port 5432 from another security group
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_port_5432_from_other_sg.id]
  }

  # Define outbound rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.environment}-sec_redis_sg"
  }
}

resource "aws_ecr_repository" "frontend_repository" {
  name = "${var.environment}-frontend"
  tags = {
    Name = "${var.environment}-frontend"
  }
}

resource "aws_ecr_repository" "backend_repository" {
  name = "${var.environment}-backend"
  tags = {
    Name = "${var.environment}-backend"
  }
}

resource "aws_ecr_repository" "sidekiq_repository" {
  name = "${var.environment}-sidekiq"
  tags = {
    Name = "${var.environment}-sidekiq"
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.environment}-cluster"
  tags = {
    Environment = "${var.environment}"
    Project     = "Streamocracy"
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "${var.environment}-target-gp"
  port        = 3000              # Set the port for your target group
  protocol    = "HTTP"          # Set the protocol for your target group
  vpc_id      = aws_vpc.main.id # Set the VPC ID where the target group should be created
  target_type = "ip"

  health_check {
    path                = "/"       # Set the health check path
    protocol            = "HTTP"    # Set the health check protocol
    port                = "3000"    # Set the port for health checks
    interval            = 5         # Set the health check interval in seconds
    timeout             = 3         # Set the health check timeout in seconds
    healthy_threshold   = 2         # Set the number of consecutive successful health checks required to consider the target healthy
    unhealthy_threshold = 2         # Set the number of consecutive failed health checks required to consider the target unhealthy
    matcher             = "200-399" #Success codes
  }

  tags = {
    Name        = "${var.environment}-target-gp"
    Environment = "${var.environment}"
  }
}

resource "aws_lb" "load_balancer" {
  name               = "${var.environment}-alb" # Set the name for your load balancer
  internal           = false                    # Set to true if it's an internal load balancer
  load_balancer_type = "application"            # Set the load balancer type to "application"

  subnets = aws_subnet.public_subnets[*].id # Set the subnet IDs where the load balancer will be deployed

  security_groups = [aws_security_group.sec_group_alb.id] # Set the security group ID for the load balancer
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:961664003051:certificate/d31b3895-e5a9-4487-8c3b-7fd58fbeb501"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_db_instance" "postgres_db" {
  identifier              = var.db_identifier
  instance_class          = var.db_instance_class
  engine                  = "postgres"
  engine_version          = var.db_version
  allocated_storage       = var.db_storage
  storage_type            = "gp2"
  username                = var.db_username
  password                = var.db_password
  publicly_accessible     = false
  backup_retention_period = 7
  vpc_security_group_ids  = [aws_security_group.allow_port_5432_from_other_sg.id] # Associate RDS instance with the specified security group
  db_subnet_group_name    = aws_db_subnet_group.my_db_subnet_group.name           # Use the private subnet group

  tags = {
    Name        = "${var.environment}-db"
    Environment = "${var.environment}"
  }
}

# Create DB subnet group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "${var.environment}-db-subnet-gp"
  subnet_ids = aws_subnet.private_subnets[*].id # Use the private subnets
}
