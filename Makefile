init:
	cd terraform && terraform init

deploy:
	cd terraform && terraform apply -auto-approve

destroy:
	cd terraform && terraform destroy -auto-approve

test:
	@echo "Sending prompt to TinyLlama..."
	curl -X POST http://192.168.2.253/api/generate \
	-H "Content-Type: application/json" \
	-H "Host: tinyllama.local" \
	-d '{ "model": "tinyllama", "prompt": "Who are you?", "stream": false }'