-- This query finds all unbalanced non-equity transactions by summing the
-- splits.
select
    s.amount,
    a.name,
    t.description,
    t.posted
from account as a
    inner join (
        select transaction, sum(amount) as amount, max(account) as account
        from split
        group by transaction
        having sum(amount) <> 0
    ) as s on s.account = a.id
    inner join transaction as t on t.id = s.transaction
where a.type <> 'EQUITY'
