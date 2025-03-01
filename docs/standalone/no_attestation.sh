#!/bin/bash

# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e

PHRASE=$1

# Create a public and private key pair.
gpg --quick-generate-key --yes my.attestor@example.com
gpg --armor --export my.attestor@example.com > gpg.pub
gpg --armor --export-secret-keys my.attestor@example.com > gpg.priv

kubectl create secret generic attestor --from-file=public=gpg.pub --from-file=private=gpg.priv --from-literal=passphrase=${PHRASE}

PUBLIC_KEY=`base64 gpg.pub -w 0`

# Create AttestationAuthority CRD in the k8s cluster. It will be used to enforce
# the GenericAttestationPolicy.
cat <<EOF | kubectl apply -f - \

apiVersion: kritis.grafeas.io/v1beta1
kind: AttestationAuthority
metadata:
  name: kritis-authority
  namespace: default
spec:
  noteReference: v1beta1/projects/standalone
  privateKeySecretName: my-attestor
  publicKeyData: $PUBLIC_KEY
EOF

# Create GenericAttestationPolicy that references the AttestationAuthority we
# just created.
cat <<EOF | kubectl apply -f - \

apiVersion: kritis.grafeas.io/v1beta1
kind: GenericAttestationPolicy
metadata:
  name: my-gap
  namespace: default
spec:
  attestationAuthorityNames:
  - kritis-authority
EOF

kubectl delete pods java
kubectl apply -f pod.yaml
