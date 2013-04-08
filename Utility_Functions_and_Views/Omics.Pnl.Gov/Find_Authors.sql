-- Note that the queries are case-sensitive
SELECT *
FROM "public"."publication_authors"
WHERE last_name LIKE 'Yang%' OR
      last_name LIKE 'Tempel%' OR
      last_name LIKE 'Cambronne%' OR
      last_name LIKE 'Petyuk%' OR
      last_name LIKE 'Jones%' OR
      last_name LIKE 'Gritsenko%' OR
      last_name LIKE 'Monroe%' OR
      last_name LIKE 'Yang%' OR
      last_name LIKE 'Smith%' OR
      last_name LIKE 'Adkins%' OR
      last_name LIKE 'Heffron%'


-- Associate authors with a publication
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 249, 2);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 250, 3);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 203, 4);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 127, 5);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 104, 6);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 5  , 7);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 252, 8);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 9  , 9);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 17 , 10);
insert into publication_author_xref (publication_id, author_id, listing_order) values (1080, 15 , 11);