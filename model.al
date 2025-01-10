{:name :Odoo
 :agentlang-version "current"
 :components [:Odoo.Core]
 :dependencies [[org.clojure/algo.monads "0.2.0"]
                [necessary-evil/necessary-evil "2.0.1"]]
 :connection-types
  [{:name :Odoo/Connection
    :type :Odoo.Core/ConnectionConfig
    :title "Configure Odoo Connection"
    :description "provide api-url, db-name username and password for connecting to Odoo"}]}
