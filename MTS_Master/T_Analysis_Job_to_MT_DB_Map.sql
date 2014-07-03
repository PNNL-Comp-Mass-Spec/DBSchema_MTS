/****** Object:  Table [dbo].[T_Analysis_Job_to_MT_DB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Job_to_MT_DB_Map](
	[Server_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
	[MT_DB_ID] [int] NOT NULL,
	[ResultType] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created] [datetime] NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Process_State] [int] NOT NULL,
 CONSTRAINT [PK_T_Analysis_Job_to_MT_DB_Map] PRIMARY KEY CLUSTERED 
(
	[Server_ID] ASC,
	[Job] ASC,
	[MT_DB_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Analysis_Job_to_MT_DB_Map]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Job_to_MT_DB_Map_T_MTS_Servers] FOREIGN KEY([Server_ID])
REFERENCES [dbo].[T_MTS_Servers] ([Server_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Job_to_MT_DB_Map] CHECK CONSTRAINT [FK_T_Analysis_Job_to_MT_DB_Map_T_MTS_Servers]
GO
