
/*
** From https://www.simple-talk.com/sql/t-sql-programming/quickly-investigating-whats-in-the-tables-of--sql-server-databases/
**
** Creates an HTML file with the first three rows of data in all tables in a database
** Can limit the tables to view using a wildcard
*/

Set nocount on
SET ARITHABORT ON      

--------------------------------
-- User-definable parameters
--------------------------------
--
-- Define the tables to match, using format schema.TableNameSpec
-- Use '%.%' to match all tables
-- Use '%Job%' to match all tables with "Job" in the name, using the current schema
DECLARE @WildCardName VARCHAR(150)

-- Full path of the directory where you want to store the file (Ignored if @SaveToDisk = 0)
-- This is a folder path on the Server
-- The server must have the bcp program in the search path
DECLARE @Directory VARCHAR(255)

-- Set to 0 to preview the first 8000 characters of the HTML (limit imposed by Sql Server Management Studio)
DECLARE @SaveToDisk tinyint

Set @WildCardName  ='%.%'
Set @Directory='c:\temp\'
Set @SaveToDisk = 1


--------------------------------
-- Validate the inputs
--------------------------------
--
If Len(@Directory) > 0 
Begin
	If Right(@Directory, 1) <> '\' Set @Directory = @Directory + '\'
End

--------------------------------
-- Declare variables
--------------------------------
--
DECLARE @FileNameAndPath VARCHAR(255) -- the path and the file
DECLARE @ColumnList NVARCHAR(MAX) -- comma delimited list of columns
DECLARE @x XML, @HTML VARCHAR(MAX), @Row VARCHAR(MAX), @CrLf CHAR(2)
DECLARE @Contents NVARCHAR(MAX)
DECLARE @Errors NVARCHAR(MAX)
DECLARE @SQL NVARCHAR(MAX) -- the dynamic SQL that we create
DECLARE @ii INT ,@iiMax INT -- the counters for our loop
DECLARE @TheTable VARCHAR(2000) -- the name of the table being documented
DECLARE @tablesToDo TABLE(TheOrder INT IDENTITY,TheTable VARCHAR(2000))


-- If no Schema was specified, we'll assume all schemas are intended
DECLARE @columnsToDo TABLE (FirstBadCharacter int ,name varchar(255),
		  RedactedName varchar(255), column_ID int)

IF PARSENAME(@WildCardName,2) IS NULL
	SELECT @WildCardName='%.'+@WildCardName;

--------------------------------
-- Find table names to export
--------------------------------
--
INSERT INTO @tablesToDo (TheTable) -- insert the names in order into the table
SELECT QUOTENAME(schema_name([schema_ID]))+'.'+QUOTENAME(name)
FROM sys.tables
WHERE name LIKE PARSENAME(@WildCardName,1) -- the table name
    AND schema_name([schema_ID]) LIKE PARSENAME(@WildCardName,2) -- the schema
ORDER BY schema_name([schema_ID]),name;  -- order by schema, followed by name  

-- Nothing found? We warn the user and abort.
IF @@rowcount=0 -- if we found nothing
BEGIN
Select @errors='<H4>No such table like '''+@WildCardName+''' in this database</H4>';
    -- return 1
END

--------------------------------
-- Loop through each table, creating 
-- the HTML table that shows the first three rows
--------------------------------
--
SELECT @CrLf = CHAR(13) + CHAR(10),
       @Contents = '',
       @HTML = '',
       @ii = 1,
       @iiMax = MAX(TheOrder)
FROM @tablesToDo;

WHILE @ii<=@iiMax
BEGIN
    -- get the name and schema of the next table to do
    SELECT @TheTable = TheTable,
           @ii = @ii + 1
    FROM @tablesToDo
    WHERE TheOrder = @ii;

    SELECT @Contents = @Contents + '<li><a href="#table' + CONVERT(varchar(5), @ii) + '">' + @TheTable + 
           '</a></li>' + @CrLf;

    /* get the name of the column and take out any problem characters for XML and HTML */
    Delete from @columnsToDo 
    
	INSERT INTO @columnsToDo( FirstBadCharacter,
	                          name,
	                          RedactedName,
	                          Column_ID )
	SELECT Patindex('%[^a-zA-Z_0-9]%', NAME COLLATE Latin1_General_CI_AI),
	       Name,
	       Name,
	       Column_ID
	FROM sys.columns
	WHERE OBJECT_NAME([object_id]) LIKE PARSENAME(@TheTable, 1) AND
	      object_schema_name([object_ID]) LIKE PARSENAME(@TheTable, 2)

    While Exists (Select * from @columnsToDo where FirstBadCharacter > 0)
    Begin
		UPDATE @columnsToDo
		SET RedactedName = stuff(RedactedName, FirstBadCharacter, 1, '_')
		WHERE FirstBadCharacter > 0

		UPDATE @columnsToDo
		SET FirstBadCharacter = Patindex('%[^a-zA-Z_0-9]%', RedactedName COLLATE Latin1_General_CI_AI)
		WHERE FirstBadCharacter > 0
    End

	SELECT @ColumnList=STUFF((
            SELECT ',['+name+'] AS ['+RedactedName+'] '
                FROM @columnsToDo
                ORDER BY column_ID
                        FOR XML PATH (''), TYPE).value('.', 'varchar(max)') ,1,1,'');

    -- get the top three rows (meaningless as we haven't specified the order) as XML
    SELECT @SQL=N'Select @TheXML=((Select top 3 '+@columnList+' from '+@TheTable
                +' for XML path, ELEMENTS XSINIL, root))'

    EXECUTE sp_ExecuteSQL  @statement =  @SQL,
        @params = N'@TheXML XML  OUTPUT',
        @TheXML = @x output
    
	-- now we do the TABLE tag in HTML with the name of the table and the caption
    SELECT @HTML = @HTML + '<table id="table' + CONVERT(varchar(5), @ii) + 
'" class="tablecontents" border="1"
summary="first three rows in table''' + @TheTable + '''">
<caption>' + @TheTable + '</caption>
<thead>
<tr>
',
           @Row = ''

    -- If no data there then we just give the column names taken from the system tables.
    IF @X IS NULL -- no XML output from the executed batch
    BEGIN -- just adding in all the column names in the header
        SELECT @HTML=@html+'<th>'+name+'</th>'+@CrLf
        FROM @columnsToDo
        ORDER BY column_ID
        
		SELECT @HTML=@HTML+'</tr></thead>'
    END
    Else -- it was valid XML result so there was data.
    BEGIN
        -- get the heading line for the column names 
        SELECT  @HTML=@HTML+'<th>'+[x].value('local-name(.)', 'varchar(100)')+'</th>',-- +@CrLf,
            @Row=@row+'<td>'+REPLACE(REPLACE(COALESCE([x].value('text()[1]','varchar(100)'),'NULL'),'<','&lt;'),'>','&gt;')+'</td>'-- +@CrLf
        FROM @x.nodes('root/row[1]/*')  AS a(x)
        
		-- and add it to the table
        SELECT @html=@HTML+'</tr></thead>'+@CrLf+'<tbody><tr>'+@Row+'</tr>'+@CrLf, @row=''

        -- now we collect the data from  any second row
        SELECT @Row=@Row+'<td>'+REPLACE(REPLACE(COALESCE([x].value('text()[1]','varchar(100)'),'NULL'),'<','&lt;'),'>','&gt;')+'</td>'-- +@CrLf
            FROM @x.nodes('root/row[2]/*')  AS a(x)
            -- if there was a second row we add it.
        IF @@Rowcount>0
        SELECT @html=@HTML+'<tr>'+@Row+'</tr>'+@CrLf, @row=''

        -- now we get the third row if there is one
        SELECT @Row=@Row+'<td>'+REPLACE(REPLACE(COALESCE([x].value('text()[1]','varchar(100)'),'NULL'),'<','&lt;'),'>','&gt;')+'</td>'--  +@CrLf
        FROM @x.nodes('root/row[3]/*')  AS a(x)
        
		IF @@Rowcount>0
            SELECT @html=@HTML+@CrLf+'<tr>'+@Row+'</tr>',@row=''
    End

    SELECT @html=@HTML+'</tbody></table>'
END

--------------------------------
-- Now we have all the data we need, 
-- we turn it into an HTML page merely 
-- by adding the CSS and the basic page elements
--------------------------------
--	
SELECT @HTML='<!DOCTYPE html>
<html>
<head>
<title>'+@@Servername+'-' +DB_NAME()+'</title>
</head>
<style>
<!--
 
.columnar { columns: 4; -moz-column-width: 15em; -webkit-column-width:15em; column-width: 15em; }
 
.thetables { }
 
/* do the basic style for the entire table */
.thetables table {
   border-collapse: collapse;
   border: none ;
   font: 11px Verdana, Geneva, Arial, Helvetica, sans-serif;
   color: black;
   margin-left:20px;
   margin-top: 20px;
 
    }
/*attach the styles to the caption of the table */
.thetables table caption {
  font-weight: bold;
  text-align:left;
  padding-left:5px;
  background-color: #f3f3f3;
}
  
/*give every cell the same style of border */
.thetables table td, .thetables table th, .thetables table caption { border: 1px solid #bbbde1  ;  vertical-align: top;  }
/* apply styles to the odd headers */
.thetables table th:nth-child(odd) { background-color: #cedfe2; }
/* apply styles to the even headers */
.thetables table tr th:nth-child(even) { background-color: #dfebee; }
 /* apply styles to the even rows */
.thetables table td {background-color: #f0f7f9;}
 
.thetables table tr:nth-child(even) td:nth-child(odd){background-color: #f7fafb;  }
 /* apply styles to the even colums of odd rows */
.thetables table tr:nth-child(odd) td:nth-child(even){ background-color: #f7fafb; }
 
h1, ol { color: #000000; text-align: left; font: normal 11px Verdana, Geneva, Arial, Helvetica, sans-serif; }
 
h1 { font-size: 16px; font-weight: bold; color: #000000; text-align: left; }
-->
</style>
 
<body>
<h1>Sample of contents of tables in '+@@Servername+'-'+DB_NAME()+'</h1>
<div class="columnar"><ol>'+@Contents+'</ol></div>
<div class="thetables">   
'    +Coalesce(@HTML,'')+coalesce(@errors,'')+'
</div>
</body>
</html>'

If @SaveToDisk = 0
Begin
	Print @html
End
Else
Begin
	--------------------------------
	-- Save the HTML to disk
	--------------------------------
	--
	SELECT @FileNameAndPath=@Directory+REPLACE(REPLACE(REPLACE(@@Servername+'-'+DB_NAME(),'/',''),'\',''),':','')+'.html'
	
	-- Could call sp_SaveTextToFile using the following,
	-- but have instead embedded the t-sql
	--
	-- EXECUTE master.dbo.sp_SaveTextToFile @html, @FileNameAndPath

	-- <sp_SaveTextToFile>
	Declare @Unicode int = 0

	DECLARE @MySpecialTempTable VARCHAR(255)
	DECLARE @Command NVARCHAR(4000)
	DECLARE @RESULT INT

	-- Firstly we create a global temp table with a unique name
	SELECT  @MySpecialTempTable = '##temp' + CONVERT(VARCHAR(12), CONVERT(INT, RAND() * 1000000))
	
	-- Then we create it using dynamic SQL, and insert a single row
	-- in it with the MAX Varchar stocked with the string we want
	SELECT  @Command = 'create table ['
		+ @MySpecialTempTable
		+ '] (MyID int identity(1,1), Bulkcol varchar(MAX))
	insert into ['
		+ @MySpecialTempTable
		+ '](BulkCol) select @html'

	EXECUTE sp_ExecuteSQL @command, N'@html varchar(MAX)',
			@html

	-- Execute the BCP to save the file
	SELECT  @Command = 'bcp "select BulkCol from ['
			+ @MySpecialTempTable + ']'
			+ '" queryout '
			+ @FileNameAndPath + ' '
			+ CASE WHEN @Unicode=0 THEN '-c' ELSE '-w' END
			+ ' -T -S' + @@servername
	EXECUTE @RESULT= MASTER..xp_cmdshell @command, NO_OUTPUT
	EXECUTE ( 'Drop table ' + @MySpecialTempTable )

	-- </sp_SaveTextToFile>

End
