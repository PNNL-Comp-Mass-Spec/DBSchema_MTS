/****** Object:  StoredProcedure [dbo].[GetParamFileModInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetParamFileModInfo
/****************************************************
**
**	Desc:
**	For given analysis parameter file, look up
**	potential dynamic and actual static modifications 
**	and return description of them as set of strings 
**
**	Return values: 0: success, otherwise, error code
** 
**	Auth:	grk
**	Date:	07/27/2004
**			08/06/2004 mem - Added @paramFileFound parameter and logging of errors to T_Log_Entries (limiting repeated logging to every 15 minutes)
**			08/22/2004 grk - Changed to use consolidated mod description design
**			02/25/2005 mem - Increased parameter file re-caching frequency from 15 minutes to 90 minutes
**			02/12/2006 mem - Updated call to PostLogEntry to set @duplicateEntryHoldoffHours to 1
**    
*****************************************************/
(
	@parameterFileName varchar(128) = 'sequest_N14_NE_STY_Phos_Stat_Deut_Met.params',
	@paramFileID int output,
	@paramFileFound tinyint=0 output,
	@PM_TargetSymbolList varchar(128) output,
	@PM_MassCorrectionTagList varchar(512) output,
	@NP_MassCorrectionTagList varchar(512) output,
	@message varchar(256) output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	set @paramFileFound = 0
	set @message = ''
	
	set @PM_TargetSymbolList = ''
	set @PM_MassCorrectionTagList = ''
	set @NP_MassCorrectionTagList  = ''
	
	declare @lastUpdate datetime

	-----------------------------------------------------------
	-- Get information from local cache table 
	-- if present and fresh enough 
	-----------------------------------------------------------
	--
	
	SELECT
		@paramFileID = Param_File_ID,
		@PM_TargetSymbolList = PM_Target_Symbol_List,
		@PM_MassCorrectionTagList = PM_Mass_Correction_Tag_List,
		@NP_MassCorrectionTagList  = NP_Mass_Correction_Tag_List,
		@lastUpdate = Last_Update
	FROM T_Param_File_Mods_Cache
	WHERE (Parameter_File_Name = @parameterFileName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error trying to get cached mod info'
		goto done
	end

	-----------------------------------------------------------
	-- if we found a fresh copy, we are good to go
	-----------------------------------------------------------
	declare @foundCopy int
	set @foundCopy = @myRowCount 
	
	if @foundCopy = 1 AND DATEDIFF ( minute , ISNULL(@lastUpdate, '1/1/2000') , getdate() ) < 90
	begin
		set @paramFileFound = 1
		goto done
	end

	-----------------------------------------------------------
	-- Get info from system 
	-----------------------------------------------------------
	declare @result int
	--
	set @myError = 1 -- in case sproc not called at all
	set @message = 'Failed to call GetParamFileModInfo'
	--
	exec @myError = gigasax.DMS5.dbo.GetParamFileModInfo
							@parameterFileName,
							@paramFileID output,
							@paramFileFound output,
							@PM_TargetSymbolList output,
							@PM_MassCorrectionTagList output,
							@NP_MassCorrectionTagList output,
							@message output

	if @myError <> 0
	begin
		goto done
	end
	
	if @paramFileFound = 0
	begin
		if @foundCopy = 1
			-- Param file not found, but a cached copy exists; we'll use the cached copy,
			set @message = 'Parameter file ' + @parameterFileName + ' not returned by GetParamFileModInfo but an out-of-date copy is cached in T_Param_File_Mods_Cache; will use the out-of-date copy anyway'
		else
			-- Param file is completely unknown
			set @message = 'Unknown parameter file name: ' + @parameterFileName

		-- Post an error to T_Log_Entries, limiting to one entry every hour
		Exec PostLogEntry 'Error',  @message, 'GetParamFileModInfo', 1
		
		if @foundCopy = 0
			Goto Done
	end
	

	-----------------------------------------------------------
	-- refresh local cache
	-----------------------------------------------------------
	if @foundCopy > 0
		begin
			if @paramFileFound = 1
			begin
				UPDATE T_Param_File_Mods_Cache
				SET 
					Param_File_ID = @paramFileID,
					PM_Target_Symbol_List = @PM_TargetSymbolList,
					PM_Mass_Correction_Tag_List = @PM_MassCorrectionTagList,
					NP_Mass_Correction_Tag_List = @NP_MassCorrectionTagList,
					Last_Update = GETDATE()
				WHERE (Parameter_File_Name = @parameterFileName)
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount
			end
		end
		else
		begin
			INSERT INTO T_Param_File_Mods_Cache (
				Parameter_File_Name,
				Param_File_ID,
				PM_Target_Symbol_List,
				PM_Mass_Correction_Tag_List,
				NP_Mass_Correction_Tag_List ,
				Last_Update
				)
			VALUES (
				@parameterFileName,
				@paramFileID,
				@PM_TargetSymbolList,
				@PM_MassCorrectionTagList,
				@NP_MassCorrectionTagList,
				getdate()
				)
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
		end
	--
	if @myError <> 0
	begin
		set @message = 'Error updating cached mod info'
		goto done
	end

	-----------------------------------------------------------
	-- Exit
	-----------------------------------------------------------
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetParamFileModInfo] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetParamFileModInfo] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[GetParamFileModInfo] TO [MTS_DB_Lite] AS [dbo]
GO
