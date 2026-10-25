#!/usr/bin/env bash
#
# Integrity checks for the MicrocontrollerFirm schema.
#
# Loading without errors only proves the SQL parses. These checks prove the
# schema actually enforces what it claims: that the CHECK constraints reject
# bad data, that the UNIQUE and foreign keys hold, and that the BEFORE INSERT
# trigger fills in the default it is supposed to fill in.
#
# Usage (after loading 01..06):
#   MYSQL_PWD=root ./test/schema_checks.sh
#
# Environment: DB_HOST, DB_PORT, DB_USER (defaults: 127.0.0.1, 3306, root)

set -uo pipefail

DB=MicrocontrollerFirm
MYSQL=(mysql -h "${DB_HOST:-127.0.0.1}" -P "${DB_PORT:-3306}" -u"${DB_USER:-root}"
       --batch --skip-column-names "$DB")

checks=0
failed=0

ok()  { checks=$((checks+1)); echo "  [ok]   $1"; }
bad() { checks=$((checks+1)); failed=$((failed+1)); echo "  [FAIL] $1"; }

query() { "${MYSQL[@]}" -e "$1" 2>/dev/null; }

expect_eq() { # label, sql, expected
    local got
    got=$(query "$2")
    if [ "$got" = "$3" ]; then ok "$1: $got"; else bad "$1: got '$got', want '$3'"; fi
}

expect_ge() { # label, sql, minimum
    local got
    got=$(query "$2")
    if [ -n "$got" ] && [ "$got" -ge "$3" ] 2>/dev/null; then
        ok "$1: $got (>= $3)"
    else
        bad "$1: got '$got', want at least $3"
    fi
}

must_reject() { # label, sql  -- the statement HAS to be refused
    if "${MYSQL[@]}" -e "$2" >/dev/null 2>&1; then
        bad "$1 was ACCEPTED; the rule is not being enforced"
    else
        ok "$1 rejected, as it should be"
    fi
}

echo "=== Objects created ==="
expect_eq "base tables" \
  "SELECT COUNT(*) FROM information_schema.tables
   WHERE table_schema='$DB' AND table_type='BASE TABLE';" 17
expect_eq "views" \
  "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='$DB';" 4
expect_eq "triggers" \
  "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='$DB';" 1
expect_ge "foreign keys" \
  "SELECT COUNT(*) FROM information_schema.table_constraints
   WHERE table_schema='$DB' AND constraint_type='FOREIGN KEY';" 10

echo
echo "=== Seed data loaded ==="
expect_ge "microcontrollers"  "SELECT COUNT(*) FROM Microcontrollers;"  1
expect_ge "manufacturers"     "SELECT COUNT(*) FROM Manufacturers;"     1
expect_ge "orders"            "SELECT COUNT(*) FROM Orders;"            1
expect_ge "order details"     "SELECT COUNT(*) FROM OrderDetails;"      1

echo
echo "=== CHECK constraints actually reject bad data ==="
must_reject "FoundedYear below the allowed range (1850)" \
  "INSERT INTO Manufacturers (CompanyName, FoundedYear)
   VALUES ('CI probe bad year', 1850);"
must_reject "FoundedYear above the allowed range (2200)" \
  "INSERT INTO Manufacturers (CompanyName, FoundedYear)
   VALUES ('CI probe future', 2200);"
must_reject "Website not matching 'https://www.%'" \
  "INSERT INTO Manufacturers (CompanyName, Website)
   VALUES ('CI probe bad site', 'http://example.com');"
must_reject "Phone not matching the REGEXP format" \
  "INSERT INTO MicrocontrollerSuppliers (CompanyName, Phone)
   VALUES ('CI probe bad phone', 'not-a-phone');"

echo
echo "=== Keys hold ==="
query "INSERT INTO Manufacturers (CompanyName, Country, FoundedYear, Website)
       VALUES ('CI probe unique', 'RO', 2000, 'https://www.example.com');"
must_reject "duplicate CompanyName (UNIQUE)" \
  "INSERT INTO Manufacturers (CompanyName) VALUES ('CI probe unique');"
must_reject "microcontroller pointing at a missing manufacturer (FK)" \
  "INSERT INTO Microcontrollers (ManufacturerID, SupplierID, CategoryID, ModelName)
   VALUES (999999, 1, 1, 'CI probe orphan');"

echo
echo "=== BEFORE INSERT trigger fills the default ==="
query "INSERT INTO Categories (CategoryName) VALUES ('CI probe category');"
expect_eq "NULL description becomes UNKNOWN" \
  "SELECT Description FROM Categories WHERE CategoryName='CI probe category';" "UNKNOWN"

# leave the database as we found it
query "DELETE FROM Categories    WHERE CategoryName='CI probe category';"
query "DELETE FROM Manufacturers WHERE CompanyName='CI probe unique';"

echo
echo "------------------------------------------------------------------------"
if [ "$failed" -eq 0 ]; then
    echo "All $checks checks passed."
else
    echo "$failed of $checks checks FAILED."
fi
exit $(( failed == 0 ? 0 : 1 ))
