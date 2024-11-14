  ## No Mess Rollouts with Argo Rollouts and Gateway API
  
  Modern application delivery has many pitfalls: version transitions,
  traffic management, quality assurance, performance monitoring, and rollbacks.
  Argo Rollouts lets teams gradually and safely deploy new versions of applications.
  A standard Gateway API enables any provider to support Argo Rollouts without
  provider-specific code.


  This hands-on lab guides you on integrating Argo Rollouts using different Gateway API implementations.
  Using Argo and Gateway API resources (HTTPRoute),
  you’ll learn to adjust traffic weights and gradually direct more traffic
  to a new version. We will also explore challenges in route delegation
  and role-based access control within Gateway API.

To setup run:
```
./setup-env.sh
```

To clean up the setup:
```
./teardown.sh
```