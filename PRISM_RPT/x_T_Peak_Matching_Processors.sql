/****** Object:  Table [dbo].[x_T_Peak_Matching_Processors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[x_T_Peak_Matching_Processors](
	[PM_AssignedProcessorName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Active] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Processors_Active]  DEFAULT (1),
 CONSTRAINT [PK_T_Peak_Matching_Processors] PRIMARY KEY CLUSTERED 
(
	[PM_AssignedProcessorName] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
