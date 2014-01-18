-- Shows accounts that aren't categorized.

select a.id, a.name, a.type
from account as a
    left join account_category as ac on a.id = ac.account
where ac.account is null
