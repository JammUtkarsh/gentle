#!/bin/sh
# To checks for the presence of the AWS_LAMBDA_RUNTIME_API environment variable.
if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
  exec /usr/local/bin/aws-lambda-rie /usr/local/bin/python -m awslambdaric $@
else
  exec /usr/local/bin/python -m awslambdaric $@
fi  