/****** Object:  StoredProcedure [dbo].[GetProteinsIdentifiedOutputColumns] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE dbo.GetProteinsIdentifiedOutputColumns
/****************************************************
**
**	Desc: 
**	Returns the valid column names for the 
**  GetProteinsIdentified SP
**        
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @message				-- Status/error message output
**	  @pepIdentMethod		-- Can be DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)
**
**		Auth: mem
**		Date: 05/12/2005
**    
*****************************************************/
(
	@message varchar(512) = '' output,
	@pepIdentMethod varchar(32) = 'DBSearch(MS/MS-LCQ)'
)
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	
	---------------------------------------------------
	-- resolve match method name to internal code
	---------------------------------------------------
	declare @internalMatchCode varchar(32)
	set @internalMatchCode = ''
	--
	SELECT @internalMatchCode = Internal_Code
	FROM T_Match_Methods
	WHERE ([Name] = @pepIdentMethod)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0 or @internalMatchCode = ''
	begin
		set @message = 'Could not resolve match methods'
		goto Done
	end


	---------------------------------------------------
	-- create a temporary table to hold the column names
	---------------------------------------------------
	
	CREATE TABLE #OutputColumns (
		UniqueID int IDENTITY (1, 1) NOT NULL ,
		Column_Name varchar (255) NOT NULL ,
		Data_Type varchar (255) NOT NULL
	)   

	---------------------------------------------------
	-- populate the table with the valid column names
	---------------------------------------------------
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Experiment', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Protein_Name', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Mass_Tag_Count', 'int')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_ObservationCount_Avg', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_High_Normalized_Score_Avg', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_High_Discriminant_Score_Avg', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Mod_Count_Avg', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Dataset_Count_Avg', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Job_Count_Avg ', 'float')

/*
	If @internalMatchCode = 'UMC'
	Begin
		-- Custom columns would go here
	End
	Else
	Begin
		-- Custom columns would go here
	End
*/	

	---------------------------------------------------
	-- return the names in a ResultSet
	---------------------------------------------------
	
	SELECT Column_Name, Data_Type
	FROM #OutputColumns
	ORDER BY UniqueID

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetProteinsIdentifiedOutputColumns] TO [DMS_SP_User]
GO
