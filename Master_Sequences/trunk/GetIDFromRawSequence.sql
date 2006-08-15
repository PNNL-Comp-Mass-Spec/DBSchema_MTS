/****** Object:  StoredProcedure [dbo].[GetIDFromRawSequence] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetIDFromRawSequence
/****************************************************
** 
**	Desc:  
**		Returns the unique ID for the given peptide raw sequence
**
**      The raw sequence is first normalized and then
**      looked for in the main sequence table.
**      A new entry is made if it cannot be found.
**
**		The mod parameters for normalization can be
**      cached in the calling routine: if @parameterFileName
**      is blank, the values in the arguments will be used
**      otherwise they will be looked up
**
**	Return values: 0: success, otherwise, error code
**
**	Auth:	grk
**	Date:	07/24/2004
**			07/27/2004 grk - moved mod parameters to argument list
**			08/06/2004 mem - Added @paramFileFound parameter
**			08/23/2004 grk - changed to consolidated mod description parameters
**			08/24/2004 mem - Added @cleanSequence, @modCount, and @modDescription outputs
**			02/26/2005 mem - Consolidated the code a bit and updated the comment for the @mapID parameter
**			06/07/2006 mem - Added support for Protein Collection File IDs and removed input parameter @mapID
**    
*****************************************************/
(
	@rawSequence varchar(128) = 'k.abcdefghijklmnopqrs*tuvwxy*z.r', --'R.RHPYFYAPELLYYANK.Y', --'k.abc*defghij#klmnopqrst@uvwxyz.r',
	@parameterFileName varchar(512) = 'sequest_N14_NE_STY_Phos_Stat_Deut_Met.params', -- 'sequest_N14_NE_Dyn_M1_M2_Ox_C_Iodo.params',
	@OrganismDBFileID int=0,				-- Organism DB file ID; if @OrganismDBFileID is non-zero, then @ProteinCollectionFileID is ignored; adds SeqID and MapID to T_Seq_Map if non-zero and not yet present
	@ProteinCollectionFileID int=0,			-- Protein collection file ID; adds SeqID and MapID to T_Seq_to_Archived_Protein_Collection_File_Map if non-zero and not yet present
	@paramFileFound tinyint=0 output,
	@seqID int output,
	@PM_TargetSymbolList varchar(128)='' output,
	@PM_MassCorrectionTagList varchar(512)='' output,
	@NP_MassCorrectionTagList varchar(512)='' output,
	@cleanSequence varchar(512)='' output,
	@modCount int=0 output,
	@modDescription varchar(2048)='' output,
	@message varchar(256) = '' output
)
As
	Set NoCount On
	
	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @cleanSequence = ''
	set @modCount = 0
	set @modDescription = ''
	set @seqID = 0
			
	set @message = ''

	declare @paramFileID int
	
	-----------------------------------------------------------
	-- get modification info for parameter file
	-- (if parameter file name is given, otherwise depend on 
	--  values contained in arguments)
	-----------------------------------------------------------
	if @parameterFileName <> ''
	begin
		exec @myError = GetParamFileModInfo
							@parameterFileName,
							@paramFileID output,
							@paramFileFound  output,
							@PM_TargetSymbolList output,
							@PM_MassCorrectionTagList output,
							@NP_MassCorrectionTagList output,
							@message  output
		--
		if @myError <> 0 or @paramFileFound = 0
			goto Done
	end
	-----------------------------------------------------------
	-- 
	-----------------------------------------------------------

	exec @myError = NormalizeSequenceWithMods
						@rawSequence,
						@PM_TargetSymbolList,
						@PM_MassCorrectionTagList,
						@NP_MassCorrectionTagList,
						@cleanSequence output,
						@modDescription output,
						@modCount output,
						@message output
	--
	if @myError <> 0
		goto Done

	-----------------------------------------------------------
	-- 
	-----------------------------------------------------------
	
	exec @myError = GetIDFromNormalizedSequence
						@cleanSequence,
						@modDescription,
						@modCount,
						@OrganismDBFileID,
						@ProteinCollectionFileID,
						@seqID output,
						@message output

	-----------------------------------------------------------
	-- exit
	-----------------------------------------------------------
	
Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetIDFromRawSequence] TO [DMS_SP_User]
GO
