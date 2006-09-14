/****** Object:  StoredProcedure [dbo].[UpdateCachedHistograms] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdateCachedHistograms
/****************************************************
**
**	Desc:	Recomputes the histograms in T_Histogram_Cache with Auto_Update = 1 
**			and Query_Date < @QueryDateThreshold
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	03/13/2006 mem
**    
*****************************************************/
(
	@QueryDateThreshold datetime=NULL ,			-- If defined, then histograms with Query_Date >= @QueryDateThreshold will not be recomputed
	@HistogramModeFilter smallint = -1,			-- Set to 0 or greater to only invalidate cached histograms for the given histogram mode, and, if necessary, histograms that use certain parameters as minima
	@InvalidateButDoNotProcess tinyint = 0,
	@UpdateIfRequired tinyint = 0,				-- Set to 1 to only update if any histograms have Histogram_Cache_State = 2
	@UpdateCount int = 0 output,
	@message varchar(255) = '' output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @UpdateCount = 0
	set @message = ''
	
	Declare @HistogramCacheID int
	Declare @ResultTypeFilter varchar(32)

	Declare @Continue int
	Declare @MatchCount int
	Declare @UpdateEnabled tinyint

	Declare @InvalidationCount int
	Set @InvalidationCount = 0
	
	-----------------------------------------------------
	-- Validate the inputs
	-----------------------------------------------------
	--	
	Set @QueryDateThreshold = IsNull(@QueryDateThreshold, GetDate())
	Set @HistogramModeFilter = IsNull(@HistogramModeFilter, -1)
	Set @InvalidateButDoNotProcess = IsNull(@InvalidateButDoNotProcess, 0)
	Set @UpdateIfRequired = IsNull(@UpdateIfRequired, 0)
	Set @message = ''

	If @UpdateIfRequired <> 0
	Begin
		Set @InvalidateButDoNotProcess = 0

		SELECT @MatchCount = COUNT(*)
		FROM T_Histogram_Cache
		WHERE Histogram_Cache_State = 2

		If @MatchCount = 0
			Goto Done
	End
	Else
	Begin	
		-----------------------------------------------------
		-- Invalidate all entries in T_Histogram_Cache with Query_Date < @QueryDateThreshold
		-- Optionally match @HistogramModeFilter
		-----------------------------------------------------
		--
		UPDATE T_Histogram_Cache
		SET Histogram_Cache_State = CASE WHEN Auto_Update = 1 THEN 2 ELSE 0 END
		WHERE Query_Date < @QueryDateThreshold AND 
			  (@HistogramModeFilter < 0 OR Histogram_Mode = @HistogramModeFilter)
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error
		--
		Set @InvalidationCount = @myRowCount

		If @HistogramModeFilter = 4
		Begin
			-- Also need to invalidate histograms with PMT_Quality_Score_Minimum defined
			UPDATE T_Histogram_Cache
			SET Histogram_Cache_State = CASE WHEN Auto_Update = 1 THEN 2 ELSE 0 END
			WHERE Query_Date < @QueryDateThreshold AND 
				  PMT_Quality_Score_Minimum > 0
			--
			SELECT @myRowCount = @@rowcount, @myError = @@error
			--
			Set @InvalidationCount = @InvalidationCount + @myRowCount
		
		End
	End
	
	-----------------------------------------------------
	-- Process each entry in T_Histogram_Cache with Auto_Update = 1 and Histogram_Cache_State = 2
	-- However, do not process if @InvalidateButDoNotProcess = 1
	-----------------------------------------------------
	--
	If @InvalidateButDoNotProcess = 0
	Begin
		Set @HistogramCacheID = -1
		Set @Continue = 1
	End
	Else
	Begin
		Set @Continue = 0
	End
	
	While @Continue = 1 AND @myError = 0
	Begin -- <a>
		SELECT	TOP 1 @HistogramCacheID = Histogram_Cache_ID
		FROM	T_Histogram_Cache
		WHERE	Histogram_Cache_State = 2 AND
				Histogram_Cache_ID > @HistogramCacheID
		ORDER BY Histogram_Cache_ID
		--
		SELECT @myRowCount = @@rowcount, @myError = @@error

		If @myRowCount = 0 OR @myError <> 0
		Begin
			Set @Continue = 0
		End
		Else
		Begin -- <b>
			exec @myError = GenerateHistogram @HistogramCacheIDOverride = @HistogramCacheID, @message = @message output

			If @myError <> 0
			Begin
				If Len(@message) = 0
					Set @message = 'Error calling GenerateHistogram (code = ' + Convert(varchar(12), @myError) + ')'
				Goto Done
			End
			
			Set @UpdateCount = @UpdateCount + 1
			
			-- Validate that updating is enabled, abort if not enabled
			exec VerifyUpdateEnabled @CallingFunctionDescription = 'UpdateCachedHistograms', @AllowPausing = 1, @UpdateEnabled = @UpdateEnabled output, @message = @message output
			If @UpdateEnabled = 0
				Goto Done
				
		End -- </b>

	End -- </a>
	
Done:
	If @myError = 0
	Begin
		If @UpdateCount = 0
		Begin
			If @InvalidationCount > 0
				Set @message = 'Invalidated cached histograms but did not re-process'
			Else
				Set @message = 'Update not required'
		End
		Else
			Set @message = 'Updated ' + Convert(varchar(12), @UpdateCount) + ' cached histograms'
	End

	Return @myError


GO
