
#  exit the script if any command exits with a non-zero exit code
set -e

echo "====== Deploying Barcode Server ======"
echo


./build_and_push.sh

# deploy to elastic beanstalk

cd eb

echo
echo "====== Deploying to Elastic Beanstalk ======"
echo

eb deploy

# docker run -p 8080:8080 -e LOG_LEVEL=info barcode-server:latest

# docker build -t barcode-server:latest . && \
#     docker run -p 8080:8080 -e LOG_LEVEL=info barcode-server:latest

# logs:
# https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups$3FlogGroupNameFilter$3Dbarcode-server
#
# logs tail /aws/elasticbeanstalk/barcode-server-vpc-env/var/log/eb-docker/containers/eb-current-app/stdouterr.log --follow
