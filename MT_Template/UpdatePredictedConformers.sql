/****** Object:  StoredProcedure [dbo].[UpdatePredictedConformers] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.UpdatePredictedConformers
/****************************************************
**
**	Desc:	Adds any missing entries to T_Mass_Tag_Conformers_Predicted
**
**			In addition, looks for peptides where Avg_Obs_NET differs from 
**			T_Mass_Tags_NET.Avg_GANET and changes Update_Required to 1
**			where a difference is found
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	10/21/2010 mem
**			03/23/2011 mem - Now updating Last_Affected in T_Mass_Tag_Conformers_Predicted
**    
*****************************************************/
(
	@message varchar(255) = '' output
)
AS
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	-----------------------------------------------------
	-- Add new data to T_Mass_Tag_Conformers_Predicted
	-----------------------------------------------------
	--	
	INSERT INTO T_Mass_Tag_Conformers_Predicted( Mass_Tag_ID,
	                                             Charge,
	                                             Avg_Obs_NET,
	                                             Update_Required,
	                                             Last_Affected )
	SELECT SourceQ.Mass_Tag_ID,
	       SourceQ.Charge_State,
	       SourceQ.Avg_GANET,
	       1 AS Update_Required,
	       GetDate()
	FROM ( SELECT MT.Mass_Tag_ID,
	              MTN.Avg_GANET,
	              Pep.Charge_State
	       FROM T_Mass_Tags MT
	            INNER JOIN T_Mass_Tags_NET MTN
	              ON MT.Mass_Tag_ID = MTN.Mass_Tag_ID
	            INNER JOIN T_Peptides Pep
	              ON MT.Mass_Tag_ID = Pep.Mass_Tag_ID
	       WHERE NOT MTN.Avg_GANET IS NULL
	       GROUP BY MT.Mass_Tag_ID, MTN.Avg_GANET, Pep.Charge_State 	       
	     ) SourceQ
	     LEFT OUTER JOIN T_Mass_Tag_Conformers_Predicted
	       ON SourceQ.Mass_Tag_ID = T_Mass_Tag_Conformers_Predicted.Mass_Tag_ID 
	          AND
	          SourceQ.Charge_State = T_Mass_Tag_Conformers_Predicted.Charge
	WHERE (T_Mass_Tag_Conformers_Predicted.Mass_Tag_ID IS NULL)
	--
	SELECT @myError = @@Error, @myRowCount = @@RowCount


	-----------------------------------------------------
	-- Look for data where the NET value has changed
	-----------------------------------------------------
	--	
	UPDATE T_Mass_Tag_Conformers_Predicted
	SET Update_Required = 1, Last_Affected = GetDate()
	FROM T_Mass_Tag_Conformers_Predicted MTC
		INNER JOIN T_Mass_Tags_NET MTN
		ON MTC.Mass_Tag_ID = MTN.Mass_Tag_ID AND
			MTC.Avg_Obs_NET <> MTN.Avg_GANET
	WHERE NOT (MTN.Avg_GANET IS NULL) AND
		 Update_Required = 0
	--
	SELECT @myError = @@Error, @myRowCount = @@RowCount
		
Done:

	Return @myError


GO
