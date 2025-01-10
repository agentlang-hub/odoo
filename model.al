{:name :Odoo
 :agentlang-version "current"
 :github-org "agentlang-hub",
 :github-url "https://github.com/agentlang-hub/odoo"
 :components [:Odoo.Core]
 :dependencies [[org.clojure/algo.monads "0.2.0"]
                [necessary-evil/necessary-evil "2.0.1"]]
 :connection-types
  [{:name :Odoo/Connection
    :type :Odoo.Core/ConnectionConfig
    :title "Configure Odoo Connection"
    :description "provide api-url, db-name username and password for connecting to Odoo"}]}
