/****** Object:  Table [dbo].[T_Joined_Job_Details] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Joined_Job_Details](
	[Joined_Job_ID] [int] NOT NULL,
	[Source_Job] [int] NOT NULL,
	[Section] [smallint] NOT NULL,
	[Peptide_ID_Start] [int] NULL,
	[Peptide_ID_End] [int] NULL,
	[Scan_Number_Start] [int] NULL,
	[Scan_Number_End] [int] NULL,
	[Scan_Time_Start] [real] NULL,
	[Scan_Time_End] [real] NULL,
	[Gap_to_Next_Section_Minutes] [real] NULL CONSTRAINT [DF_T_Joined_Job_Details_Gap_to_Next_Section_Minutes]  DEFAULT (0),
	[Scan_Number_Added] [int] NULL CONSTRAINT [DF_T_Joined_Job_Details_Scan_Number_Added]  DEFAULT (0),
	[Scan_Time_Added] [real] NULL CONSTRAINT [DF_T_Joined_Job_Details_Scan_Time_Added]  DEFAULT (0),
 CONSTRAINT [PK_T_Joined_Job_Details] PRIMARY KEY CLUSTERED 
(
	[Joined_Job_ID] ASC,
	[Section] ASC
) ON [PRIMARY],
 CONSTRAINT [IX_T_Joined_Job_Details] UNIQUE NONCLUSTERED 
(
	[Joined_Job_ID] ASC,
	[Source_Job] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Joined_Job_Details]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Joined_Job_Details_T_Analysis_Description_MetaJob_ID] FOREIGN KEY([Joined_Job_ID])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Joined_Job_Details] CHECK CONSTRAINT [FK_T_Joined_Job_Details_T_Analysis_Description_MetaJob_ID]
GO
ALTER TABLE [dbo].[T_Joined_Job_Details]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Joined_Job_Details_T_Analysis_Description_Source_Job] FOREIGN KEY([Source_Job])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Joined_Job_Details] CHECK CONSTRAINT [FK_T_Joined_Job_Details_T_Analysis_Description_Source_Job]
GO
