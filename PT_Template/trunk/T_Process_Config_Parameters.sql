/****** Object:  Table [dbo].[T_Process_Config_Parameters] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Process_Config_Parameters](
	[Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Function] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Min_Occurrences] [smallint] NOT NULL CONSTRAINT [DF_T_Process_Config_Parameters_Min_Occurrences]  DEFAULT (1),
	[Max_Occurrences] [smallint] NOT NULL CONSTRAINT [DF_T_Process_Config_Parameters_Max_Occurrences]  DEFAULT (99),
	[Description] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Process_Config_Parameters] PRIMARY KEY CLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
