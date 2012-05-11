/****** Object:  StoredProcedure [dbo].[AddMatchMakingFDR] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddMatchMakingFDR
/******************************************************* 	
**	Adds row to the T_Match_Making_FDR table
**
**	Returns 0 if success; error number on failure
**
**	Auth:	mem
**	Date:	10/08/2010 mem - Initial Version
**			10/11/2010 mem - Added parameters UPFilteredMatches, UPFilteredErrors, and UPFilteredFDR
**			11/01/2010 mem - Added parameters UniqueAMTs and UPFilteredUniqueAMTs and rearranged the order of the parameters
**			06/21/2011 mem - Added parameters UniqueConformers and UPFilteredUniqueConformers
**			06/27/2011 mem - Removed parameters @Matches and @UPFilteredMatches (deprecated in June 2011)
**			11/10/2011 mem - Added parameters @wSTACUniqueAMTs, @wSTACUniqueConformers, and @wSTACFDR
**
*******************************************************/
(
	@MDID int,
	@STAC_Cutoff real, 
    @UniqueAMTs int,						-- Unique number of AMT tags
	@FDR real,								-- FDR at this cutoff
	@Errors real,							-- Estimate for the number of errors at this cutoff
    @UPFilteredUniqueAMTs int,				-- Unique number of AMT tags, filtered on UP > 0.5
    @UPFilteredFDR real,					-- FDR at this cutoff, filtered on UP > 0.5
    @UPFilteredErrors real,					-- Estimate for the number of errors at this cutoff, filtered on UP > 0.5
    @UniqueConformers int,					-- Unique number of IMS conformers identified
    @UPFilteredUniqueConformers int,		-- Unique number of IMS conformers identified, filtered on UP > 0.5
    @wSTACUniqueAMTs int,					-- Unique number of AMT tags
    @wSTACUniqueConformers int,				-- Unique number of IMS conformers identified
	@wSTACFDR real							-- FDR at this cutoff
    
)
As
	Set NoCount On

	declare @ReturnValue int
	set @ReturnValue=0
		
	-- Append new row to the T_Match_Making_FDR table
	--
	INSERT INTO T_Match_Making_FDR( MD_ID,
	                                STAC_Cutoff,
	                                Unique_AMTs,
	                                FDR,
	                                Errors,
	                                UP_Filtered_Unique_AMTs,
	                                UP_Filtered_FDR, 
	                                UP_Filtered_Errors,
	                                Unique_Conformers,
	                                UP_Filtered_Unique_Conformers,
	                                wSTAC_Unique_AMTs,
	                                wSTAC_Unique_Conformers,
	                                wSTAC_FDR
	                               )
	VALUES(	@MDID, @STAC_Cutoff, @UniqueAMTs, @FDR, @Errors,
			@UPFilteredUniqueAMTs, @UPFilteredFDR, @UPFilteredErrors,
			@UniqueConformers, @UPFilteredUniqueConformers,
			@wSTACUniqueAMTs, @wSTACUniqueConformers,  @wSTACFDR )
	
	set @ReturnValue = @@ERROR

	return @ReturnValue


GO
GRANT EXECUTE ON [dbo].[AddMatchMakingFDR] TO [DMS_SP_User] AS [dbo]
GO
