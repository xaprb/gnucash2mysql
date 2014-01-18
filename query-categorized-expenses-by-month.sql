-- This query creates a pivot table of categorized expenses by month.  It
-- assumes your data is for one year only.
select ac.category,
    coalesce(sum((month(x.posted) = 1) * x.amount), 0) as Jan,
    coalesce(sum((month(x.posted) = 2) * x.amount), 0) as Feb,
    coalesce(sum((month(x.posted) = 3) * x.amount), 0) as Mar,
    coalesce(sum((month(x.posted) = 4) * x.amount), 0) as Apr,
    coalesce(sum((month(x.posted) = 5) * x.amount), 0) as May,
    coalesce(sum((month(x.posted) = 6) * x.amount), 0) as Jun,
    coalesce(sum((month(x.posted) = 7) * x.amount), 0) as Jul,
    coalesce(sum((month(x.posted) = 8) * x.amount), 0) as Aug,
    coalesce(sum((month(x.posted) = 9) * x.amount), 0) as Sep,
    coalesce(sum((month(x.posted) = 10) * x.amount), 0) as Oct,
    coalesce(sum((month(x.posted) = 11) * x.amount), 0) as Nov,
    coalesce(sum((month(x.posted) = 12) * x.amount), 0) as `Dec`,
    coalesce(sum(x.amount), 0) as Total
from account_category as ac
    left outer join (
        select s.account, s.amount, t.posted
        from transaction as t
            inner join split as s on t.id = s.transaction
            inner join account_category as ac on ac.account = s.account
            left outer join (
                -- Find all transactions involved in an equity account
                select distinct s.transaction
                from split as s
                    inner join account as a on s.account = a.id
                where a.type in ('EQUITY')
            ) as x on x.transaction = s.transaction
        -- Exclude the equity transactions
        where x.transaction is null
    ) as x on x.account = ac.account
group by ac.category
with rollup
