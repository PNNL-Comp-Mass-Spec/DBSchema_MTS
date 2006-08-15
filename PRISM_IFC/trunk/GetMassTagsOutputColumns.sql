/****** Object:  StoredProcedure [dbo].[GetMassTagsOutputColumns] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetMassTagsOutputColumns
/****************************************************
**
**	Desc: 
**	Returns the valid column names for the 
**  GetMassTags SP
**        
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	  @message				-- Status/error message output
**	  @pepIdentMethod		-- Can be DBSearch(MS/MS-LCQ) or UMCPeakMatch(MS-FTICR)
**
**		Auth: mem
**		Date: 4/12/2004
**			  4/14/2004 mem - Added Data_Type column to output ResultSet
**			  4/28/2004 mem - Added the MT_Abundance_Total column
**			  9/23/2004 grk - replaced ORF with Protein
**			 10/27/2004 mem - Added three columns (MSMS_High_Discriminant_Score, & MT.Mod_Count, MT.Mod_Description)
**			 05/12/2005 mem - Added new columns (MSMS_DeltaCn2_Maximum, MS_Dataset_Count, MS_Job_Count, MSMS_Dataset_Count, MSMS_Job_Count, SLiC_Score_Maximum)
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
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Mass_Tag_ID', 'int')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Mass_Tag_Name', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Peptide_Sequence', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Peptide_Monoisotopic_Mass', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_Observation_Count', 'int')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_High_Normalized_Score', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_DeltaCn2_Maximum', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_High_Discriminant_Score', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Mod_Count', 'int')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Mod_Description', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('PMT_Quality_Score', 'float')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Cleavage_State_Name', 'varchar')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Residue_Start', 'int')
	INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Residue_End', 'int')

	If @internalMatchCode = 'UMC'
	Begin
		INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MS_Dataset_Count', 'int')
		INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MS_Job_Count', 'int')

		INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('Peak_Matching_Task_Count', 'int')
		INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('SLiC_Score_Maximum', 'float')
		INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MT_Abundance_Avg', 'float')
	End
	Else
	Begin
		INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_Dataset_Count', 'int')
		INSERT INTO #OutputColumns (Column_Name, Data_Type) Values ('MSMS_Job_Count', 'int')
	End
	
	---------------------------------------------------
	-- return the names in a ResultSet
	---------------------------------------------------
	
	SELECT Column_Name, Data_Type
	FROM #OutputColumns
	ORDER BY UniqueID

Done:
	return @myError


GO
GRANT EXECUTE ON [dbo].[GetMassTagsOutputColumns] TO [DMS_SP_User]
GO
