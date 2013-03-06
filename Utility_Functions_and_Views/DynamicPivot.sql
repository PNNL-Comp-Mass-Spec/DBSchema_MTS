CREATE PROCEDURE DynamicPivot
/****************************************************
**
**	Desc:	Dynamically creates the SQL needed to run
**			a PIVOT query against a table
**
**			Modelled after code posted to http://www.experts-exchange.com/articles/Microsoft/Development/MS-SQL-Server/SQL-Server-2005/Dynamic-Pivot-Procedure-for-SQL-Server.html
**			Original versio by Mark Wills, posted 05/15/09 at 12:32 PM
**
**
**	Auth:	mem
**	Date:	09/23/2009 mem - Initial version
**
*****************************************************/
(
	@SourceTable varchar(8000),					-- Name of the source table
	@Pivot_On_Source_Column varchar(2000),		-- Column name (or names) for which data will be summarized (e.g., Protein, Peptide)
	@Pivot_Value_Aggregate varchar(10),			-- Examples values: Sum, Max, Min, Avg, Count
	@Pivot_Value_Column varchar(2000),			-- Column name to aggregate (e.g. Abundance)
	@Pivot_Column_List varchar(2000),			-- Column name to examine to determine the column header names (e.g. Condition)
	@Pivot_Column_Style_Code varchar(4),		-- Number format to apply to the column headers (only useful if your headers will be dates); For example, use "106" for format dates as "dd mmm yyyy"
	@infoOnly TINYINT = 0,
	@message varchar(512)='' output,
	@PivotSQL nvarchar(max)='' output
) 
AS 
	Declare @myError int
	Declare @myRowCount int
		
	declare @columns varchar(max)
	declare @sql nvarchar(max)

	-- Clean up the inputs
	
	Set @SourceTable = IsNull(@SourceTable, '')
	Set @Pivot_On_Source_Column = IsNull(@Pivot_On_Source_Column, '')
	Set @Pivot_Value_Aggregate = IsNull(@Pivot_Value_Aggregate, '')
	Set @Pivot_Value_Column = IsNull(@Pivot_Value_Column, '')
	Set @Pivot_Column_List = IsNull(@Pivot_Column_List, '')
	Set @Pivot_Column_Style_Code = LTrim(IsNull(@Pivot_Column_Style_Code, ''))
	
	Set @message= ''
	Set @PivotSQL = ''
	
	If @SourceTable = ''
	Begin
		Set @myError = 50000
		Set @message = 'Source table not defined: ' + @SourceTable
		Goto Done
	End
	
	If NOT EXISTS (SELECT * FROM SYS.TABLES WHERE Name = @SourceTable)
	Begin
		Set @myError = 50000
		Set @message = 'Source table not found: ' + @SourceTable
		Goto Done
	End
	
	
	If @Pivot_Column_Style_Code <> ''
	Begin
		-- Make sure @Pivot_Column_Style_Code starts with a comma
		If Substring(@Pivot_Column_Style_Code, 1, 1) <> ','
			Set @Pivot_Column_Style_Code = ',' + @Pivot_Column_Style_Code
	End
		
	
	set @sql = N'set @columns = substring((select '', [''+convert(varchar,'+@Pivot_Column_List+@Pivot_Column_Style_Code+')+'']'' from '+@SourceTable+' group by '+@Pivot_Column_List+' for xml path('''')),2,8000)'
	
	If @infoOnly <> 0
		Print @sql
	
   execute sp_executesql @sql,
						 N'@columns varchar(max) output',
						 @columns=@columns output 
 
	set @PivotSQL = N'SELECT * FROM 
	   (SELECT '+@Pivot_On_Source_Column+','+@Pivot_Column_List+','+@Pivot_Value_Column+' FROM '+@SourceTable+') src
	   PIVOT
	   ('+@Pivot_Value_Aggregate+'('+@Pivot_Value_Column+') FOR '+@Pivot_Column_List+' IN ('+@columns+') ) pvt
	   ORDER BY 1'
       
	If @infoOnly <> 0
		Print @PivotSQL
	Else
		execute sp_executesql @PivotSQL

	---------------------------------------------------
	-- Exit
	---------------------------------------------------
	--
Done:

	If @myError <> 0 and @infoOnly <> 0
		Print @Message
 
GO


GRANT EXECUTE ON [dbo].[DynamicPivot] TO [DMS_SP_User] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[DynamicPivot] TO [MTS_DB_Dev] AS [dbo]
GO

GRANT VIEW DEFINITION ON [dbo].[DynamicPivot] TO [MTS_DB_Lite] AS [dbo]
GO


