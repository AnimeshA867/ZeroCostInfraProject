.PHONY: up verify chaos status down

up: ## Boot LocalStack, provision Terraform, start API + Observability
	docker compose up -d localstack prometheus grafana
	@echo "Waiting for LocalStack to become healthy..."
	@until docker inspect --format='{{.State.Health.Status}}' localstack | grep -q "healthy"; do sleep 2; done
	cd terraform && terraform init && terraform apply -auto-approve
	docker compose up -d --build api-service
	@echo "Waiting for API service healthcheck..."
	@sleep 5
	@echo "Stack Ready! Grafana -> http://localhost:3000 (admin/admin)"

verify: ## Run Ansible hardening checks & smoke tests
	cd ansible && ansible-playbook -i inventory.ini harden-and-verify.yml

chaos: ## Flood 150 orders and restart API container to trigger Grafana spikes
	@echo "Injecting load spike and container restart..."
	@for i in $$(seq 1 150); do \
		curl -s -X POST http://localhost:8000/order \
		-H "Content-Type: application/json" \
		-d '{"item":"chaos-item","quantity":1}' > /dev/null & \
	done
	docker restart api-service
	@echo "Check Grafana at http://localhost:3000/d/zerocost-infraops"

status: ## Check live RAM usage across all containers
	docker stats --no-stream

down: ## Tear down Terraform state and wipe all containers/volumes
	cd terraform && terraform destroy -auto-approve || true
	docker compose down -v --remove-orphans