if exists (select * from dbo.sysobjects where id = object_id(N'[T_Tmp_Seq_Map_ID_Summary]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Tmp_Seq_Map_ID_Summary]
GO

CREATE TABLE [T_Tmp_Seq_Map_ID_Summary] (
	[Map_ID] [smallint] NULL ,
	[FileName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Organism] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[FileNameBase] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
) ON [PRIMARY]
GO


