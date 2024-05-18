
#  exit the script if any command exits with a non-zero exit code
set -e

echo "====== Deploying Barcode Server ======"
echo

./build_and_push.sh

# deploy to elastic beanstalk

echo
echo "====== Deploying to Elastic Beanstalk ======"
echo

eb deploy
