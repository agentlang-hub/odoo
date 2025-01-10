(component
 :Odoo.Core
 {:clj-import
  (quote
   [(:require [necessary-evil.core :as xml-rpc]
              [agentlang.component :as cn]
              [agentlang.connections.client :as cc]
              [agentlang.util.logger :as log]
              [agentlang.resolver.registry :as rr]
              [agentlang.resolver.core :as rc]
              [agentlang.lang.internal :as li])])})

(def odoo-enabed? (System/getenv "ODOO_USER"))

;; Ref: https://gist.github.com/zerg000000/9ca413b7481426c2dedde38cb1f51246
(defn authenticate
  "Attempt acquire uid if it is not already exists in `conn`"
  [conn]
  (if-not (contains? conn :uid)
    (assoc conn :uid (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/common")
                                   "authenticate" (:db conn) (:username conn) (:password conn) {}))
    conn))

(defn fields
  "Return the definition of each field.
   The returned value is a dictionary (indexed by field name) of dictionaries.
   The _inherits’d fields are included. The string, help, and selection (if present) attributes are translated.   
   https://www.odoo.com/documentation/saas-17.2/developer/reference/backend/orm.html#id7"
  [conn domain & {:keys [allfields attributes]
                  :or {allfields []
                       attributes []}}]
  (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/object") "execute_kw"
                (:db conn) (:uid conn) (:password conn)
                domain "fields_get" allfields attributes))

(defn read-object
  "Read the requested fields for the records in self, and return their values as a list of dicts."
  [conn domain ids fields]
  (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/object") "execute_kw"
                (:db conn) (:uid conn) (:password conn)
                domain "read" (if (vector? ids) ids [ids]) fields))

(defn search
  "Search for the records that satisfy the given domain search domain.   
   https://www.odoo.com/documentation/saas-17.2/developer/reference/backend/orm.html#odoo.models.Model.search   
   Also see. https://www.odoo.com/documentation/saas-17.2/developer/reference/backend/orm.html#search-domains"
  [conn domain search-domains {:keys [limit offset order] :as args}]
  (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/object") "execute_kw"
                (:db conn) (:uid conn) (:password conn)
                domain "search"
                search-domains
                args))

(defn search-count
  "Returns the number of records in the current model matching the provided domain.   
   https://www.odoo.com/documentation/saas-17.2/developer/reference/backend/orm.html#odoo.models.Model.search_fetch"
  [conn domain search-domains {:keys [limit] :as args}]
  (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/object") "execute_kw"
                (:db conn) (:uid conn) (:password conn)
                domain "search_count"
                search-domains
                args))

(defn search-read
  "Search for the records that satisfy the given domain search domain,
   and fetch the given fields to the cache. This method is like a combination
   of methods search() and fetch(), but it performs both tasks with a minimal number of SQL queries.   
   https://www.odoo.com/documentation/saas-17.2/developer/reference/backend/orm.html#odoo.models.Model.search_fetch"
  [conn domain search-domains {:keys [limit offset order] :as args}]
  (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/object") "execute_kw"
                (:db conn) (:uid conn) (:password conn)
                domain "search_read"
                search-domains
                args))

(defn create
  "Creates new records for the model.
   The new records are initialized using the values from the list of dicts vals_list, and if necessary those from default_get().   
   https://www.odoo.com/documentation/saas-17.2/developer/reference/backend/orm.html#odoo.models.Model.create"
  [conn domain xs]
  (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/object") "execute_kw"
                (:db conn) (:uid conn) (:password conn)
                domain "create"
                xs))

(defn write
  "Updates all records in self with the provided values."
  [conn domain ids record]
  (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/object") "execute_kw"
                (:db conn) (:uid conn) (:password conn)
                domain "write"
                [ids record]))

(defn get-connection-config []
  (or (cc/get-connection :ErpSuite/Odoo)
      {:Parameter
       {:api-url (or (System/getenv "ODOO_HOST") "http://localhost:8069/")
        :db (or (System/getenv "ODOO_DB") "odoo")
        :username (System/getenv "ODOO_USER")
        :password (System/getenv "ODOO_PASSWORD")}}))

(def ^:private get-connection
  (memoize
   (fn []
     (when odoo-enabed?
       (let [params (cc/connection-parameter (get-connection-config))
             conn (authenticate params)
             info (xml-rpc/call (str (:api-url conn) "/xmlrpc/2/common") "version")]
         (if (and (map? info) (:server_version info))
           (do (log/info (str "Odoo connection established. " info))
               conn)
           (log/error (str "Odoo connection failed. " info))))))))

(defn- lookup-by-ids [conn schema v]
  (when conn
    (let [ids (if (string? v) (read-string v) v)]
      (read-object conn schema ids []))))

(defn- lookup-by-field [conn schema field field-val]
  (when conn
    (search-read conn schema [[[field "=" field-val]]] {})))

(def ^:private order-lookups
  (let [conn (get-connection)]
    {:No (partial lookup-by-ids conn "sale.order")
     :Name (partial lookup-by-field conn "sale.order" "name")}))

(def ^:private invoice-lookups
  (let [conn (get-connection)]
    {:No (partial lookup-by-ids conn "account.move")
     :Name (partial lookup-by-field conn "account.move" "name")}))

(def ^:private lookup-nil (constantly nil))

(defn- normalize-invoice [schema-norm obj]
  (when (seq obj)
    (let [order (first ((:Name order-lookups) (:invoice_origin obj)))]
      (schema-norm obj order))))

(defn- query-instances [norm-fns [entity-name {where :where}]]
  (let [[opr attr-name attr-val] where
        [_ ename] (li/split-path entity-name)]
    (when (= opr :=)
      (case ename
        :Order
        (mapv (ename norm-fns) ((get order-lookups attr-name lookup-nil) attr-val))
        :Invoice
        (let [lookup (get invoice-lookups (if (number? attr-val) :No :Name))]
          (mapv (partial normalize-invoice (ename norm-fns)) (lookup attr-val)))
        nil))))

(defn- update-instance [instance]
  ;; TODO: lift-out :Reconciled and :No access to schema.al
  (let [[_ ename] (li/split-path (cn/instance-type instance))]
    (when (and (= :Invoice ename) (:Reconciled instance))
      (write (get-connection) "account.move"
             [(:No instance)]
             {:payment_state "paid"
              :status_in_payment "paid"})))
  instance)

(defn register-resolver [paths norm-fns]
  (when odoo-enabed?
    (let [methods {:query (partial query-instances norm-fns)
                   :update update-instance}
          res (rc/make-resolver :Odoo.Core/Resolver methods)]
      (rr/override-resolver paths res))))
