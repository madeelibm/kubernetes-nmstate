package selectors

import (
	"github.com/go-logr/logr"

	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	nmstatev1 "github.com/nmstate/kubernetes-nmstate/api/v1"
)

type Selectors struct {
	client client.Client
	policy nmstatev1.NodeNetworkConfigurationPolicy
	logger logr.Logger
}

func NewFromPolicy(client client.Client, policy nmstatev1.NodeNetworkConfigurationPolicy) Selectors {
	selectors := Selectors{
		client: client,
		policy: policy,
	}
	selectors.logger = logf.Log.WithName("policy/selectors").WithValues("policy", policy.Name)
	return selectors
}
