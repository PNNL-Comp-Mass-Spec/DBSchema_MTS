/****** Object:  Table [dbo].[T_QR_Export_Job] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_QR_Export_Job](
	[jobkey] [int] IDENTITY(1,1) NOT NULL,
	[modified] [datetime] NOT NULL,
	[statuskey] [int] NOT NULL,
	[dbname] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[qid_list] [varchar](500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[result] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[email_address] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[prot_column] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[pep_column] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[rep_cnt_avg_min] [float] NOT NULL,
	[propep_select] [smallint] NOT NULL,
	[crosstab_select] [smallint] NOT NULL,
	[send_mail] [smallint] NOT NULL,
	[gen_pep] [bit] NOT NULL,
	[include_prot] [bit] NOT NULL,
	[gen_prot] [bit] NOT NULL,
	[gen_prot_crosstab] [bit] NOT NULL,
	[prot_avg] [bit] NOT NULL,
	[gen_pep_crosstab] [bit] NOT NULL,
	[pep_avg] [bit] NOT NULL,
	[gen_propep_crosstab] [bit] NOT NULL,
	[Verbose_Output_Columns] [bit] NOT NULL,
 CONSTRAINT [PK_T_QR_Export_Job] PRIMARY KEY CLUSTERED 
(
	[jobkey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_QR_Export_Job] ADD  CONSTRAINT [DF_T_QR_Export_Job_Verbose_Output_Columns]  DEFAULT (0) FOR [Verbose_Output_Columns]
GO
