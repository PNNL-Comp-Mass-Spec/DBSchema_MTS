SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SearchForString]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SearchForString]
GO

CREATE PROCEDURE dbo.SearchForString
/****************************************************
**
**	Desc: 
**      Searches for the given search text in the
**	given database.  If @DBName is '', then searches
**	this database.
**
**	Auth: mem
**	Date: 12/15/2004
**
**
*****************************************************/
(
	@SearchText varchar(1000) = 'Gigasax',
	@DBName varchar(255) = ''
)
AS
	set nocount on
	
	Declare @S varchar(2048)
	Declare @myRowCount int
	Declare @myError int

	Set @DBName = IsNull(@DBName, '')
	If Len(@DBName) = 0
		Set @DBName = DB_Name()

	Set @S = ''
	Set @S = @S + ' SELECT SubString(o.name, 1, 35 ) as Object,'
	Set @S = @S + '   COUNT(*) as Occurences,'
	Set @S = @S + '   CASE '
	Set @S = @S + '   WHEN o.xtype = ''D'' THEN ''Default'''
	Set @S = @S + '   WHEN o.xtype = ''F'' THEN ''Foreign Key'''
	Set @S = @S + '   WHEN o.xtype = ''P'' THEN ''Stored Procedure'''
	Set @S = @S + '   WHEN o.xtype = ''PK'' THEN ''Primary Key'''
	Set @S = @S + '   WHEN o.xtype = ''S'' THEN ''System Table'''
	Set @S = @S + '   WHEN o.xtype = ''TR'' THEN ''Trigger'''
	Set @S = @S + '   WHEN o.xtype = ''U'' THEN ''User Table'''
	Set @S = @S + '   WHEN o.xtype = ''V'' THEN ''View'''
	Set @S = @S + '   WHEN o.xtype = ''C'' THEN ''Check Constraint'''
	Set @S = @S + '   WHEN o.xtype = ''FN'' THEN ''User Function'''
	Set @S = @S + '   ELSE o.xtype'
	Set @S = @S + '   END as Type '
	Set @S = @S + ' FROM ' + @DBName + '.dbo.syscomments AS C'
	Set @S = @S + '   INNER JOIN ' + @DBName + '.dbo.sysobjects AS O'
	Set @S = @S + '   ON C.id = O.id'
	Set @S = @S + ' WHERE PatIndex(''%' + @SearchText + '%'', c.text) > 0'
	Set @S = @S + ' GROUP BY o.name, o.xtype'
	Set @S = @S + ' ORDER BY o.xtype, o.name'

	Exec (@S)
	
	Select @myRowCount = @@RowCount, @myError = @@Error
	
	Return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

