/****** Object:  StoredProcedure [dbo].[WebGetPickerList] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.WebGetPickerList
/****************************************************
**
**	Desc: 
**	Returns list of items for pick-lists on the MTS web site
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	grk
**	Date:	10/16/2004
**			05/12/2005 mem - Added item 'OutputColumnsForIdentifiedProteins'
**			05/13/2005 mem - Updated calls to GetAllMassTagDatabases and GetAllPeptideDatabases to pass 0 to @VerboseColumnOutput
**						   - Added validation of @MTDBName when @PickerName = 'ExperimentList' or 'ProteinList'
**			02/20/2006 mem - Now validating that @MTDBName has a state less than 100 in MT_Main
**    
*****************************************************/
(
	@MTDBName varchar(128) = 'MT_BSA_P171',
	@PickerName varchar(128) = 'ProteinList',
	@pepIdentMethod varchar(32) = 'DBSearch(MS/MS-LCQ)',
	@message varchar(512) = '' output
)
As	
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0
	
	set @message = ''
	declare @result int
	

	---------------------------------------------------
	-- validate mass tag DB name for picker's that require a database name
	---------------------------------------------------
	If @PickerName = 'ExperimentList' or @PickerName = 'ProteinList'
	Begin
		Declare @DBNameLookup varchar(256)
		SELECT  @DBNameLookup = MTL_ID
		FROM MT_Main.dbo.T_MT_Database_List
		WHERE (MTL_Name = @MTDBName) AND MTL_State < 100
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 or @myRowCount <> 1
		begin
			set @message = 'Could not resolve mass tag DB name: ' + IsNull(@MTDBName, 'NULL')
			SELECT @message As ErrorMessage
			goto Done
		end
	End
	
	
	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'MTDBNameList'
	begin
--		exec @result = GetAllMassTagDatabases
--					@message  output,
--					0,			-- Set to 1 to include unused databases
--					0			-- Set to 1 to include deleted databases
		exec @myError = Pogo.MTS_Master.dbo.GetAllMassTagDatabases 
					0, 
					0, 
					'',					-- @ServerFilter
					@message output,
					0					-- @VerboseColumnOutput

		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'PTDBNameList'
	begin
--		exec @result = MTS_Master.dbo.GetAllPeptideDatabases
--					@message  output,
--					0,			-- Set to 1 to include unused databases
--					0			-- Set to 1 to include deleted databases
		exec @myError = Pogo.MTS_Master.dbo.GetAllPeptideDatabases 
					0, 
					0, 
					'',					-- @ServerFilter
					@message output,
					0					-- @VerboseColumnOutput
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'ExperimentList'
	begin
		exec @result = GetExperimentsSummary
							@MTDBName,
							@pepIdentMethod,
							'',
							@message output
		--
		goto Done
	end
	
	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'ProteinList'
	begin
		declare @ignore varchar(32)
		exec @result = GetAllProteins
							@MTDBName ,
							'Protein_Name, Protein_Description',	-- @outputColumnNameList
							'',                    -- @criteriaSql
							'False',               -- @returnRowCount
							@message output,
							'',                    -- @Proteins
							@ignore  output        -- @ProteinDBDefined
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'OutputColumnsForGetMassTags'
	begin
		exec @result = GetMassTagsOutputColumns
							@message  output,
							'DBSearch(MS/MS-LCQ)'
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'OutputColumnsForGetAllProteins'
	begin
		exec @result = GetAllProteinsOutputColumns
							@message  output
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'OutputColumnsForIdentifiedProteins'
	begin
		exec @result = GetProteinsIdentifiedOutputColumns
							@message  output,
							@pepIdentMethod
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'OutputColumnsForProteinCrosstab'
	begin
		exec @result = QRProteinCrosstabOutputColumns
							@message  output
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'OutputColumnsForPeptideCrosstab'
	begin
		exec @result = QRPeptideCrosstabOutputColumns
							@message  output
		--
		goto Done
	end

	---------------------------------------------------
	-- 
	---------------------------------------------------

	if @PickerName = 'QRSummary'
	begin
		exec @result = WebGetQRollupsSummary
							@MTDBName,
							@message output
		--
		goto Done
	end

	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[WebGetPickerList] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebGetPickerList] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebGetPickerList] TO [MTS_DB_Lite] AS [dbo]
GO
