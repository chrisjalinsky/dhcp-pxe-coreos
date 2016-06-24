CoreOS Baremetal
================

Important Notes:
* The ignition scripts are fairly complex and should be templated. Notice the raw/endraw opening template tags, these allow the Kubernetes templating characters to work as usual. If you need to inject Ansible variables, close with endraw, and reopen after the variable

* The groups and profiles contain the variables anyhow, so these can be passed into the role--as they currently are. See the defaults/main.yml file for examples and more info.

Jinja templating example:
```
template stuff here...{% endraw %}  {{ ansible_variable_here }} {% raw %} carry on with template stuff...
```