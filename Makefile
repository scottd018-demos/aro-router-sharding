# NOTE: please review article https://access.redhat.com/solutions/5097511

#
# variables
#
DOMAIN1 ?= test1.dustinscott.io
DOMAIN2 ?= test2.dustinscott.io
APP1 ?= test1
APP2 ?= test2
APP_IMAGE ?= mendhak/http-https-echo
APP_HOSTNAME ?= test

#
# routers
#

# create the sharded routers for my domains
shard:
	oc apply -f ingress-controllers.yaml

# disallow the default router from my sharded apps
shard-default:
	oc -n openshift-ingress-operator patch ingresscontroller default \
		--type='json' \
		-p='[{"op": "replace", "path": "/spec/namespaceSelector", "value": {"matchExpressions": [{"key": "kubernetes.io/metadata.name", "operator": "NotIn", "values": ["$(APP1)", "$(APP2)"]}]}}]'

# return the default router to its default settings
default:
	oc -n openshift-ingress-operator patch ingresscontroller default \
		--type='json' \
		-p='[{"op": "remove", "path": "/spec/namespaceSelector"}]'

#
# test apps
#
app1:
	oc create ns $(APP1) --dry-run=client -o yaml | oc apply -f- && \
		oc project $(APP1) && \
		oc new-app --name $(APP1) --image $(APP_IMAGE) && \
		oc expose svc/$(APP1) --hostname $(APP_HOSTNAME).$(DOMAIN1)

app2:
	oc create ns $(APP2) --dry-run=client -o yaml | oc apply -f- && \
		oc project $(APP2) && \
		oc new-app --name $(APP2) --image $(APP_IMAGE) && \
		oc expose svc/$(APP2) --hostname $(APP_HOSTNAME).$(DOMAIN1)

app1-destroy:
	oc delete ns $(APP1)

app2-destroy:
	oc delete ns $(APP2)

#
# successful tests
#
test1:
	curl $(APP_HOSTNAME).$(DOMAIN1)

test2:
	curl $(APP_HOSTNAME).$(DOMAIN2)

#
# default router traffic
#
test1-default:
	curl $(APP_HOSTNAME).$(DOMAIN1) --resolve $(APP_HOSTNAME).$(DOMAIN1):80:40.112.63.192

test2-default:
	curl $(APP_HOSTNAME).$(DOMAIN2) --resolve $(APP_HOSTNAME).$(DOMAIN2):80:40.112.63.192

#
# cross router traffic (sharded)
#
test1-cross:
	curl $(APP_HOSTNAME).$(DOMAIN1) --resolve $(APP_HOSTNAME).$(DOMAIN1):80:4.156.26.183

test2-cross:
	curl $(APP_HOSTNAME).$(DOMAIN2) --resolve $(APP_HOSTNAME).$(DOMAIN2):80:4.156.26.112
