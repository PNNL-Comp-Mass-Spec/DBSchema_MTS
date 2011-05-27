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
**
*******************************************************/
(
	@MDID int,
	@STAC_Cutoff real, 
    @UniqueAMTs int,			-- Unique number of AMT tags
	@FDR real,					-- FDR at this cutoff
	@Matches int,				-- Number of DB matches at the given STAC cutoff
	@Errors real,				-- Estimate for the number of errors at this cutoff
    @UPFilteredUniqueAMTs int,	-- Unique number of AMT tags, filtered on UP > 0.5
    @UPFilteredFDR real,			-- FDR at this cutoff, filtered on UP > 0.5,
	@UPFilteredMatches int,		-- Number of DB matches at the given STAC cutoff, filtered on UP > 0.5
    @UPFilteredErrors real		-- Estimate for the number of errors at this cutoff, filtered on UP > 0.5
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
	                                Matches,
	                                Errors,
	                                UP_Filtered_Unique_AMTs,
	                                UP_Filtered_FDR, 
	                                UP_Filtered_Matches,
	                                UP_Filtered_Errors
	                                 )
	VALUES(	@MDID, @STAC_Cutoff, @UniqueAMTs, @FDR, @Matches, @Errors,
			@UPFilteredUniqueAMTs, @UPFilteredFDR, @UPFilteredMatches, @UPFilteredErrors )
	
	set @ReturnValue = @@ERROR

	return @ReturnValue


GO
GRANT EXECUTE ON [dbo].[AddMatchMakingFDR] TO [DMS_SP_User] AS [dbo]
GO
