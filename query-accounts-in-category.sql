-- Specify a category to see what accounts belong to it.

select @category;

select a.*
from account_category as ac
    inner join account as a on a.id = ac.account
where ac.category = @category
