{:name :Odoo
 :agentlang-version "current"
 :components [:Odoo.Core]
 :connection-types
  [{:name :Odoo/Connection
    :type :Odoo.Core/ConnectionConfig
    :title "Configure Odoo Connection"
    :description "provide api-url, db-name username and password for connecting to Odoo"}]}
