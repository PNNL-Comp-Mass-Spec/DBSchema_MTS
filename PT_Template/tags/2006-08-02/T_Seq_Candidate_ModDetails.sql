if exists (select * from dbo.sysobjects where id = object_id(N'[T_Seq_Candidate_ModDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Seq_Candidate_ModDetails]
GO

CREATE TABLE [T_Seq_Candidate_ModDetails] (
	[Job] [int] NOT NULL ,
	[Seq_ID_Local] [int] NOT NULL ,
	[Mass_Correction_Tag] [char] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Position] [smallint] NOT NULL ,
	[Seq_Candidate_ModDetail_ID] [int] IDENTITY (1, 1) NOT NULL ,
	CONSTRAINT [PK_T_Seq_Candidate_ModDetails] PRIMARY KEY  CLUSTERED 
	(
		[Seq_Candidate_ModDetail_ID]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Seq_Candidate_ModDetails_T_Seq_Candidates] FOREIGN KEY 
	(
		[Job],
		[Seq_ID_Local]
	) REFERENCES [T_Seq_Candidates] (
		[Job],
		[Seq_ID_Local]
	)
) ON [PRIMARY]
GO


