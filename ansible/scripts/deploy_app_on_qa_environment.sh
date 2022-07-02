echo 'Deploying App on Kubernetes'
envsubst < k8s/petclinic_chart/values-template.yaml > k8s/petclinic_chart/values.yaml
sed -i s/HELM_VERSION/${BUILD_NUMBER}/ k8s/petclinic_chart/Chart.yaml
AWS_REGION=$AWS_REGION helm repo add stable-petclinicapp s3://petclinic-helm-charts-mbayco/stable/myapp/ || echo "repository name already exists"
AWS_REGION=$AWS_REGION helm repo update
helm package k8s/petclinic_chart
AWS_REGION=$AWS_REGION helm s3 --force push petclinic_chart-${BUILD_NUMBER}.tgz stable-petclinicapp
envsubst < ansible/playbooks/qa-petclinic-deploy-template >ansible/playbooks/qa-petclinic-deploy.yaml
ansible-playbook -i ./ansible/inventory/qa_stack_dynamic_inventory_aws_ec2.yaml ./ansible/playbooks/qa-petclinic-deploy.yaml
