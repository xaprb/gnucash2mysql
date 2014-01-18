-- This query sums all expenses for a given year by month and account.

set @year := 2005;

select date_format(posted, '%Y-%m') as month, name, sum(amount) as amount
from transaction as t
    inner join split as s on s.transaction = t.id
    inner join (
        select id, name from account
            where type='EXPENSE'
    ) as a on a.id = s.account
where year(posted) = @year
group by date_format(posted, '%Y-%m'), name
order by date_format(posted, '%Y-%m'), name;
