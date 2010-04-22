/****** Object:  StoredProcedure [dbo].[AddUpdatePeakMatchingRequests] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE AddUpdatePeakMatchingRequests
/****************************************************
**
**  Desc: 
**    Adds new or edits existing item in 
**    T_Peak_Matching_Requests
**
**  Return values: 0: success, otherwise, error code
**
**  Parameters:
**
**    Auth: grk
**    Date: 09/22/2009
**    
** Pacific Northwest National Laboratory, Richland, WA
** Copyright 2009, Battelle Memorial Institute
*****************************************************/
	@Request INT OUTPUT,
	@Name varchar(64),
	@Tool varchar(64),
	@MassTagDatabase varchar(256),
	@AnalysisJobs text,
	@Parameterfile varchar(256),
	@MinimumHighNormalizedScore varchar(12),
	@MinimumHighDiscriminantScore varchar(12),
	@MinimumPeptideProphetProbability varchar(12),
	@MinimumPMTQualityScore varchar(12),
	@LimitToPMTsFromDataset varchar(12),
	@Comment varchar(2048),
	@Requester varchar(64),
	@mode varchar(12) = 'add', -- or 'update'
	@message varchar(512) output,
	@callingUser varchar(128) = ''
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0

	set @message = ''

	---------------------------------------------------
	-- Validate input fields
	---------------------------------------------------

	-- future: this could get more complicated

	---------------------------------------------------
	-- Is entry already in database? (only applies to updates)
	---------------------------------------------------

	if @mode = 'update'
	begin
		-- cannot update a non-existent entry
		--
		declare @tmp int
		set @tmp = 0
		--
		SELECT @tmp = Request
		FROM  T_Peak_Matching_Requests
		WHERE (Request = @Request)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0 OR @tmp = 0
		begin
			set @message = 'No entry could be found in database for update'
			RAISERROR (@message, 10, 1)
			return 51007
		end
	end

	---------------------------------------------------
	-- action for add mode
	---------------------------------------------------
	if @Mode = 'add'
	begin

	INSERT INTO T_Peak_Matching_Requests (
		Name,
		Tool,
		Mass_Tag_Database,
		Analysis_Jobs,
		Parameter_file,
		MinimumHighNormalizedScore,
		MinimumHighDiscriminantScore,
		MinimumPeptideProphetProbability,
		MinimumPMTQualityScore,
		Limit_To_PMTs_From_Dataset,
		Comment,
		Requester
	) VALUES (
		@Name,
		@Tool,
		@MassTagDatabase,
		@AnalysisJobs,
		@Parameterfile,
		@MinimumHighNormalizedScore,
		@MinimumHighDiscriminantScore,
		@MinimumPeptideProphetProbability,
		@MinimumPMTQualityScore,
		@LimitToPMTsFromDataset,
		@Comment,
		@Requester
	)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Insert operation failed'
		RAISERROR (@message, 10, 1)
		return 51007
	end

	-- return ID of newly created entry
	--
	set @Request = IDENT_CURRENT('T_Peak_Matching_Requests')

	end -- add mode

	---------------------------------------------------
	-- action for update mode
	---------------------------------------------------
	--
	if @Mode = 'update' 
	begin
		set @myError = 0
		--
		UPDATE T_Peak_Matching_Requests 
		SET 
		Name = @Name,
		Tool = @Tool,
		Mass_Tag_Database = @MassTagDatabase,
		Analysis_Jobs = @AnalysisJobs,
		Parameter_file = @Parameterfile,
		MinimumHighNormalizedScore = @MinimumHighNormalizedScore,
		MinimumHighDiscriminantScore = @MinimumHighDiscriminantScore,
		MinimumPeptideProphetProbability = @MinimumPeptideProphetProbability,
		MinimumPMTQualityScore = @MinimumPMTQualityScore,
		Limit_To_PMTs_From_Dataset = @LimitToPMTsFromDataset,
		Comment = @Comment,
		Requester = @Requester
		WHERE (Request = @Request)
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Update operation failed: "' + @Request + '"'
			RAISERROR (@message, 10, 1)
			return 51004
		end
	end -- update mode

	return @myError

GO
GRANT EXECUTE ON [dbo].[AddUpdatePeakMatchingRequests] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddUpdatePeakMatchingRequests] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddUpdatePeakMatchingRequests] TO [MTS_DB_Lite] AS [dbo]
GO
