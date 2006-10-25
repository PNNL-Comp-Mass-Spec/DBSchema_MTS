/****** Object:  Table [dbo].[T_Histogram_Cache] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Histogram_Cache](
	[Histogram_Cache_ID] [int] IDENTITY(1,1) NOT NULL,
	[Histogram_Mode] [smallint] NOT NULL,
	[Score_Minimum] [float] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Score_Minimum]  DEFAULT (0),
	[Score_Maximum] [float] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Score_Maximum]  DEFAULT (0),
	[Bin_Count] [int] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Bin_Count]  DEFAULT (100),
	[Discriminant_Score_Minimum] [real] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Discriminant_Score_Minimum]  DEFAULT (0),
	[Peptide_Prophet_Probability_Minimum] [real] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Peptide_Prophet_Probability_Minimum]  DEFAULT (0),
	[PMT_Quality_Score_Minimum] [real] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_PMT_Quality_Score_Minimum]  DEFAULT (0),
	[Charge_State_Filter] [smallint] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Charge_State_Filter]  DEFAULT (0),
	[Use_Distinct_Peptides] [tinyint] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Use_Distinct_Peptides]  DEFAULT (0),
	[Result_Type_Filter] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Result_Type_Filter]  DEFAULT (''),
	[Query_Date] [datetime] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Query_Date]  DEFAULT (getdate()),
	[Result_Count] [int] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Result_Count]  DEFAULT (0),
	[Query_Speed_Category] [smallint] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Query_Speed_Category]  DEFAULT (0),
	[Execution_Time_Seconds] [real] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Execution_Time_Seconds]  DEFAULT (0),
	[Histogram_Cache_State] [smallint] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Histogram_Cache_State]  DEFAULT (0),
	[Auto_Update] [tinyint] NOT NULL CONSTRAINT [DF_T_Histogram_Cache_Auto_Update]  DEFAULT (0),
 CONSTRAINT [PK_T_Histogram_Cache] PRIMARY KEY CLUSTERED 
(
	[Histogram_Cache_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Histogram_Cache_Histogram_Mode] ******/
CREATE NONCLUSTERED INDEX [IX_T_Histogram_Cache_Histogram_Mode] ON [dbo].[T_Histogram_Cache] 
(
	[Histogram_Mode] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Histogram_Cache_Query_Date] ******/
CREATE NONCLUSTERED INDEX [IX_T_Histogram_Cache_Query_Date] ON [dbo].[T_Histogram_Cache] 
(
	[Query_Date] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Histogram_Cache_Score_Min_Max] ******/
CREATE NONCLUSTERED INDEX [IX_T_Histogram_Cache_Score_Min_Max] ON [dbo].[T_Histogram_Cache] 
(
	[Score_Minimum] ASC,
	[Score_Maximum] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Histogram_Cache]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Histogram_Cache_T_Histogram_Cache_State_Name] FOREIGN KEY([Histogram_Cache_State])
REFERENCES [T_Histogram_Cache_State_Name] ([Histogram_Cache_State])
GO
ALTER TABLE [dbo].[T_Histogram_Cache] CHECK CONSTRAINT [FK_T_Histogram_Cache_T_Histogram_Cache_State_Name]
GO
ALTER TABLE [dbo].[T_Histogram_Cache]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Histogram_Cache_T_Histogram_Mode_Name] FOREIGN KEY([Histogram_Mode])
REFERENCES [T_Histogram_Mode_Name] ([Histogram_Mode])
GO
ALTER TABLE [dbo].[T_Histogram_Cache] CHECK CONSTRAINT [FK_T_Histogram_Cache_T_Histogram_Mode_Name]
GO
ALTER TABLE [dbo].[T_Histogram_Cache]  WITH NOCHECK ADD  CONSTRAINT [CK_T_Histogram_Cache_Result_Type_Filter] CHECK  (([Result_Type_Filter] = '' or [Result_Type_Filter] = 'Peptide_Hit' or [Result_Type_Filter] = 'XT_Peptide_Hit'))
GO
ALTER TABLE [dbo].[T_Histogram_Cache] CHECK CONSTRAINT [CK_T_Histogram_Cache_Result_Type_Filter]
GO
