/****** Object:  Table [dbo].[T_Peptide_Prophet_Task_Job_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_Prophet_Task_Job_Map](
	[Task_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
 CONSTRAINT [PK_T_Peptide_Prophet_Task_Job_Map] PRIMARY KEY CLUSTERED 
(
	[Task_ID] ASC,
	[Job] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peptide_Prophet_Task_Job_Map]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Peptide_Prophet_Task_Job_Map_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Peptide_Prophet_Task_Job_Map] CHECK CONSTRAINT [FK_T_Peptide_Prophet_Task_Job_Map_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Peptide_Prophet_Task_Job_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_Prophet_Task_Job_Map_T_Peptide_Prophet_Task] FOREIGN KEY([Task_ID])
REFERENCES [T_Peptide_Prophet_Task] ([Task_ID])
GO
ALTER TABLE [dbo].[T_Peptide_Prophet_Task_Job_Map] CHECK CONSTRAINT [FK_T_Peptide_Prophet_Task_Job_Map_T_Peptide_Prophet_Task]
GO
