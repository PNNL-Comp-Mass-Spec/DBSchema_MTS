/****** Object:  Database [PT_Template_01] ******/
CREATE DATABASE [PT_Template_01]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'PT_Template_01_dat', FILENAME = N'J:\SQLServerData\PT_Template_01_data.mdf' , SIZE = 38912KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'PT_Template_01_log', FILENAME = N'L:\SQLServerData\PT_Template_01_log.ldf' , SIZE = 111616KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [PT_Template_01].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO
ALTER DATABASE [PT_Template_01] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [PT_Template_01] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [PT_Template_01] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [PT_Template_01] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [PT_Template_01] SET ARITHABORT OFF 
GO
ALTER DATABASE [PT_Template_01] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [PT_Template_01] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [PT_Template_01] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [PT_Template_01] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [PT_Template_01] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [PT_Template_01] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [PT_Template_01] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [PT_Template_01] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [PT_Template_01] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [PT_Template_01] SET  DISABLE_BROKER 
GO
ALTER DATABASE [PT_Template_01] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [PT_Template_01] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [PT_Template_01] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [PT_Template_01] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [PT_Template_01] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [PT_Template_01] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [PT_Template_01] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [PT_Template_01] SET RECOVERY FULL 
GO
ALTER DATABASE [PT_Template_01] SET  MULTI_USER 
GO
ALTER DATABASE [PT_Template_01] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [PT_Template_01] SET DB_CHAINING OFF 
GO
ALTER DATABASE [PT_Template_01] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [PT_Template_01] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [PT_Template_01] SET DELAYED_DURABILITY = DISABLED 
GO
USE [PT_Template_01]
GO
/****** Object:  User [d3m578] ******/
CREATE USER [d3m578] FOR LOGIN [PNL\D3M578] WITH DEFAULT_SCHEMA=[d3m578]
GO
/****** Object:  User [msdadmin] ******/
CREATE USER [msdadmin] FOR LOGIN [PNL\MSDADMIN] WITH DEFAULT_SCHEMA=[msdadmin]
GO
/****** Object:  User [MTAdmin] ******/
CREATE USER [MTAdmin] FOR LOGIN [mtadmin] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [MTS_DB_Dev] ******/
CREATE USER [MTS_DB_Dev] FOR LOGIN [Pogo\MTS_DB_Dev]
GO
/****** Object:  User [MTS_DB_Lite] ******/
CREATE USER [MTS_DB_Lite] FOR LOGIN [Pogo\MTS_DB_Lite]
GO
/****** Object:  User [MTS_DB_Reader] ******/
CREATE USER [MTS_DB_Reader] FOR LOGIN [Pogo\MTS_DB_Reader]
GO
/****** Object:  User [MTUser] ******/
CREATE USER [MTUser] FOR LOGIN [mtuser] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [pnl\MTSProc] ******/
CREATE USER [pnl\MTSProc] FOR LOGIN [PNL\MTSProc] WITH DEFAULT_SCHEMA=[pnl\MTSProc]
GO
/****** Object:  User [pnl\svc-dms] ******/
CREATE USER [pnl\svc-dms] FOR LOGIN [PNL\svc-dms] WITH DEFAULT_SCHEMA=[dbo]
GO
GRANT CONNECT TO [D3J410] AS [dbo]
GO
GRANT CONNECT TO [d3m578] AS [dbo]
GO
GRANT CONNECT TO [msdadmin] AS [dbo]
GO
GRANT CONNECT TO [MTAdmin] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Dev] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Dev] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Lite] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Lite] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Reader] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Reader] AS [dbo]
GO
GRANT CONNECT TO [MTUser] AS [dbo]
GO
GRANT SHOWPLAN TO [MTUser] AS [dbo]
GO
GRANT CONNECT TO [pnl\svc-dms] AS [dbo]
GO
ALTER DATABASE [PT_Template_01] SET  READ_WRITE 
GO
