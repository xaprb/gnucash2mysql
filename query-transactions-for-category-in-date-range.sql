-- Specify a category and a start and end date to see all transactions for the
-- given category in that date range.  Any of the parameters may be left NULL.

select @category, @start, @end;

select t.posted, s.amount, t.description, s.memo, a.name
from transaction as t
    inner join split as s on t.id = s.transaction
    inner join account_category as ac on ac.account = s.account
    inner join account as a on a.id = s.account
    left outer join (
        -- Find all transactions involved in an equity account
        select distinct s.transaction
        from split as s
            inner join account as a on s.account = a.id
        where a.type in ('EQUITY')
    ) as x on x.transaction = s.transaction
where ac.category = @category
    and (@start is null or t.posted >= @start)
    and (@end is null or t.posted <= @end)
    -- Exclude the equity transactions
    and x.transaction is null
order by t.posted
