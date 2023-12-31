USE [DigitalLibrary]
GO
/****** Object:  StoredProcedure [dbo].[WFSP_AC_RERC14]    Script Date: 06/10/2017 09:43:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Hale Kavoosi>
-- Create date: <06/10/2017>
-- Description:	<مقداردهی فیلدهاي پرشونده خودکار گردش جلسه سمينار جهت پذيرش در پارک علم و فناوری 

-- =============================================
ALTER PROCEDURE [dbo].[WFSP_AC_RERC14]
	@FieldName nvarchar(100),
	@DocumentCode int,
	@CreatingUsercode nvarchar(max), --کد کاربر ایجاد کننده
	@ISCompile BIT
AS
BEGIN

    DECLARE @CompanyID int--شناسه واحد فناور  
    --DECLARE @SeminarDate date--تاریخ برگزاری جلسه سمینار
	DECLARE @DTC_Seminar int --شماره جدول سمينار در مركز پارک
	DECLARE @DTC_Arbiter int --شماره جدول تعيين داور
	DECLARE @DTC_Park int --شماره جدول پارک
	DECLARE @DTC_CompanyArbiter int--شماره جدول داوران واحد فناوری
	DECLARE @DTC_Company int--شماره جدول اطلاعات واحد فناور
	DECLARE @DTC_ParkAdmissionAssessment int--كد جدول ارزیابی
    DECLARE @DTC_PersonnelCooperation int -- اطلاعات همکاری پرسنل
    
    --DECLARE @CreatingUsercode nvarchar(max) --کد کاربر ایجاد کننده
------------------------------------------------------------------------------------------------------------
	DECLARE @ArbiterDeterminationDC int --شماره ركورد گردش تعيين داور
	DECLARE @ArbiterDetermination_MainDC int --شماره ركورد اصلي گردش تعيين داور	
	DECLARE @ParkDC int --شماره ركورد کامپایل گردش تكميل اطلاعات پذيرش در مركز پارک
	DECLARE @Park_MainDC int --شماره ركورد اصلی گردش تكميل اطلاعات پذيرش در مركز پارک
	DECLARE @AssessmentFormsNO int --تعداد كل فرم هاي ارزيابي فرستاده شده براي داوران براي اين واحد فناوري
	DECLARE @ActivityFields nvarchar(max)--زمينه فعاليت واحد فناور
	DECLARE @SessionDate date --تاریخ جلسه ی شورا برای تعیین داوران برای این واحد فناور
	DECLARE @ArbitrationDate date--تاریخ داوری اولیه برای این واحد فناور
	DECLARE @Temp table(AssessmentDC int)--جدول برای نگهداری شماره رکوردهای جدول اصلی فرم های ارزیابی فرستاده شده و تکمیل شده براي اين واحد فناوري 
-------------------------------------------------------------------------------------------------------------
    select @DTC_Seminar=DocumentTypeCode FROM Docs_Infos WITH(NOLOCK)WHERE DocumentTypeName='WSI_RERC_ParkSeminar'--43
    select @DTC_Arbiter= DocumentTypeCode FROM Docs_Infos WITH(NOLOCK)WHERE DocumentTypeName='WSI_RERC_ArbiterDetermination'--57
    select @DTC_CompanyArbiter= DocumentTypeCode FROM Docs_Infos WITH(NOLOCK)WHERE DocumentTypeName='WSI_RERC_CompanyArbiter'--62
    select @DTC_Park= DocumentTypeCode FROM Docs_Infos WITH(NOLOCK)WHERE DocumentTypeName='WSI_RERC_Park'--10
    select @DTC_Company=DocumentTypeCode FROM Docs_Infos WHERE DocumentTypeName='WSI_TDOO_Company'--28
    select @DTC_ParkAdmissionAssessment =DocumentTypeCode FROM Docs_Infos WITH(NOLOCK)WHERE DocumentTypeName='WSI_RERC_ParkAdmissionAssessment'
    select @DTC_PersonnelCooperation=DocumentTypeCode FROM Docs_Infos WHERE DocumentTypeName='WSI_TDOO_PersonnelCooperation'--28

	 -------------------------------------------
	 
	DECLARE @WFInstanceCode_RERC11 int --WFInstanceCode تعيين داور قبلي 
	DECLARE @WFInstanceCode_RERC06 int --WFInstanceCode کاربرگ قبلي 
	
	IF (@ISCompile = 1)
	
		select @WFInstanceCode_RERC11= PreviousWFInstanceCode
		  from dbo.wfi_WorkflowInstances WI 
			inner join dbo.wfd_Workflows W on WI.WorkflowCode=W.WorkflowCode
				 inner join wfi_PoolInstances P on WI.PoolInstanceCode=P.PoolInstanceCode
					 where DTC=@DTC_Seminar and CompileDC=@DocumentCode 
						and W.WorkflowLetter='RERC14'
						
	else
		
		select @WFInstanceCode_RERC11= PreviousWFInstanceCode
		  from dbo.wfi_WorkflowInstances WI 
			inner join dbo.wfd_Workflows W on WI.WorkflowCode=W.WorkflowCode
				 inner join wfi_PoolInstances P on WI.PoolInstanceCode=P.PoolInstanceCode
					 where DTC=@DTC_Seminar and P.MainDC=@DocumentCode 
						and W.WorkflowLetter='RERC14'
 
	--شماره ركورد اصلي گردش تعيين داور
	select @ArbiterDetermination_MainDC= P.MainDC from dbo.wfi_PoolInstances P
		inner join wfi_WorkflowInstances WI on P.PoolInstanceCode=WI.PoolInstanceCode 
			inner join dbo.wfd_Workflows W on WI.WorkflowCode=W.WorkflowCode
				where WI.WFInstanceCode = @WFInstanceCode_RERC11 
	
	--شماره ركورد و جدول و كد گردش قبل تعيين داور 
	DECLARE @PreviousDC_Determination INT --شماره ركورد كامپايل كاربرگ
	DECLARE @PreviousWF_Determination VARCHAR(20)--كد گردش كاربرگ
	DECLARE @PreviousDTC_Determination INT--كد جدول كاربرگ
	
	--شماره ركورد و شماره جدول گردش قبل از تعيين داور
	select @Park_MainDC= P.MainDC ,@ParkDC=p.CompileDC
	from dbo.wfi_PoolInstances P With (Nolock)
	inner join wfi_WorkflowInstances WI on P.PoolInstanceCode=WI.PoolInstanceCode 
		inner join dbo.wfd_Workflows W on WI.WorkflowCode=W.WorkflowCode
			where WI.NextWFInstanceCode= @WFInstanceCode_RERC11
			
			
			
	--------------------------------------------	 
   	IF (@ISCompile = 0)
		SELECT @DocumentCode = CompileDC FROM wfi_PoolInstances WHERE DTC = @DTC_Seminar AND MainDC = @DocumentCode

	
	--جدول برای نگهداری شماره رکوردهای جدول اصلی فرم های ارزیابی فرستاده شده و تکمیل شده براي اين واحد فناوري
	Insert into @Temp (AssessmentDC)
		(select P.MainDC from wfi_PoolInstances P
		  inner join  wfi_WorkflowInstances WI With(Nolock) on  p.PoolInstanceCode=wi.PoolInstanceCode
		   inner join WSI_RERC_ParkAdmissionAssessment pa on pa.DocumentCode = p.MainDC
			 where WI.WFFinished=1 and DTC=@DTC_ParkAdmissionAssessment and RERC17H01_EstablishmentUnit <> '' 
			   and RERC17H01_EstablishmentUnit is not null
				 and WI.PreviousWFInstanceCode IN 
				  (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
					inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
					 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
					   where CompileDC=@DocumentCode and DTC=@DTC_Seminar and WF.WorkflowLetter='RERC14'))
	
 	
			
    select @CompanyID=RelatedDC from Docs_Related_Records_Compile WITH(NOLOCK) where MasterDTC=@DTC_Park and RelatedDTC=@DTC_Company
    and MasterDC=@Park_MainDC and MasterInCompile=0 and RelatedInCompile=0
        
     --تعداد كل فرم هاي ارزيابي فرستاده شده و تکمیل شده براي اين واحد فناوري
    select @AssessmentFormsNO= COUNT(*) from @Temp
    
--------------------------------------------------------------------------------------------------------------------------------
	IF @FieldName='ParkDC'	
		select @Park_MainDC
---------------------------------------------------------------------------------------------------------------
--نام تکمیل کننده ی فرم
  IF (@FieldName=N'CurrentUserName')
    select Name+N' '+Family from Users_PersonalInfo WITH(NOLOCK)where UserCode=@CreatingUsercode
  
-------------------------------------------------------------------------------------------------------------------------------- 
--نام شرکت
IF (@FieldName='CompanyName')
    select TDOO26H01_CompanyName from WSI_TDOO_Company WITH(NOLOCK)where DocumentCode=@CompanyID
--------------------------------------------------------------------------------------------------------------------------------
--شناسه شرکت
IF (@FieldName='CompanyID')
    select @CompanyID
--------------------------------------------------------------------------------------------
--اسامی مدعوين جلسه	
	IF @FieldName='Invited'

	  SELECT DISTINCT Name+N' '+Family,P.UserCode FROM Users_PersonalInfo P
		INNER JOIN Users_Roles R ON R.UserCode=P.UserCode
		 INNER JOIN Users_Roles_Managment M ON R.RoleCode=M.RoleCode			
		  INNER JOIN Orgs_Units O ON R.UnitCode=O.UnitCode
			WHERE (O.UnitLetter NOT IN ('CO','AR','OV','AD','PM','OT', 'CU', 'CUIN', 'CUPI', 'CUPA','CUSE'
			 ,'CO','AR','OV','AD','PM','OT', 'CU', 'CUIN', 'CUPI', 'CUPA','GM','SE')
			   AND M.RoleLetter NOT LIKE '%RO' AND RoleLetter NOT LIKE '%GU%' AND RoleLetter NOT LIKE 'RERC44CO%'--بجز مسئول دفترها و مدعوها
			    AND M.RoleLetter NOT IN ('INPIMA','STTDMA','TDRPMA','TDPIMA','STTDPI','STGREX','FHFIEX','FHSUEX',
				 'STTDCR','STTDSC','STTDAR','STTDAD','STTDOV' ,'FHFIEX','FHSUEX','SUSPEX','SUCOEX','FHGMEX') 
				   AND ParentUnit IN (Select UnitCode from Orgs_Units where
				    UnitLetter NOT IN('CO','AR','OV','AD','PM','OT', 'CU', 'CUIN', 'CUPI', 'CUPA')))
				     OR (O.UnitLetter='AR' and M.RoleLetter='INAR')
 

--------------------------------------------------------------------------------------------------------------------
--پرونده واحد فناور
IF @FieldName= 'Folder'
 begin
	DECLARE @REWS_AdmissionFolderLetter nvarchar(20)=Convert(nvarchar(10), @CompanyID)--كد زير پرونده واحد فناور
	
	DECLARE @CO_AdmissionFolderCode int--كد پرونده واحدهای فناور
	=(Select FolderCode from wfd_FolderCategory where FolderLetter ='CO')
	
	Select FolderCode from wfd_FolderCategory where FolderLetter = @REWS_AdmissionFolderLetter
	and ParentFolderCode = @CO_AdmissionFolderCode 
	
 end
--------------------------------------------------------------------------------------------------------------------------------
---	نام مسئول واحد فناور		
IF (@FieldName='ManagerName')
	    SELECT TDOO30H01_Name+N' '+TDOO30H01_Family FROM WSI_TDOO_Personnel_Compile WITH(NOLOCK) inner join WSI_TDOO_PersonnelCooperation
	     ON TDOO30H01_NationalCode=TDOO01H01_NationalCode where TDOO01H01_CompanyID=@CompanyID and TDOO01H01_CooperationType='Manager'
	      and TDOO01H01_Status=0 and TDOO01H02_CheckResult<>'DisConfirmation' 
--------------------------------------------------------------------------------------------------------------------------------
---	کد مسئول واحد فناور		
IF (@FieldName='ManagerCode')
	select TDOO26H01_ManagerUsercode from WSI_TDOO_Company WITH (NOLOCK)where DocumentCode=@CompanyID
---------------------------------------------------------------------------------------------------------------------------
--نام مدیر		
IF (@FieldName='ManagerFirstName')
	select Name from Users_PersonalInfo WITH(NOLOCK)where UserCode=@CreatingUsercode
---------------------------------------------------------------------------------------------------------------------------
--نام خانوادگی مدیر		
IF (@FieldName='ManagerLastName')
	select Family from Users_PersonalInfo WITH(NOLOCK)where UserCode=@CreatingUsercode

---------------------------------------------------------------------------------------------------------------------------   
---	زمينه فعاليت واحد فناور
IF (@FieldName='ActivityField')
    BEGIN
            DECLARE @ActivityFieldXML XML--زمینه های فعالیت
			DECLARE @CountXML INT --تعداد ردیف های فیلد ایکس ام ال
			DECLARE @ID INT =0 --شناسه ی زمینه ی فعالیت
			DECLARE @ActivityfieldName NVARCHAR(MAX)=N' '--مقادیر متنی زمینه های فعالیت
			DECLARE @temp2 TABLE(Field NVARCHAR(MAX), ID INT)
			   
			SELECT @ActivityFieldXML= TDOO26H01_ActivityFields_SubFields_XML FROM WSI_TDOO_Company WITH(NOLOCK) WHERE DocumentCode= @CompanyID
			
			set arithabort on                   
			SET @CountXML = @ActivityFieldXML.value('count(/Records/Record/@RowID)', 'int')
			 
			WHILE @CountXML<>'0'		  
			BEGIN 
				set arithabort on
				SET @id= @ActivityFieldXML.value(N'(Records/Record/Field[@name="TDOO26H01_ActivityFields"]/@Value)[1]','INT')

				INSERT INTO @temp2(Field, ID)
					SELECT FieldName, ID FROM dbo.YDigital_Field WHERE ID= @ID

				SET arithabort on
				SET @ActivityFieldXML.modify('delete /Records/Record [1]')
				SET @CountXML=@CountXML-1
				
				IF (@ID = 29)
				BEGIN
					DELETE @temp2 WHERE ID = @ID
					INSERT INTO @temp2(Field, ID)
						SELECT TDOO26H01_OtherActivityFields, -1 FROM WSI_TDOO_Company WITH(NOLOCK) WHERE DocumentCode= @CompanyID
				END
			END
			SELECT Field FROM @temp2 
				  
   END	
----------------------------------------------------------------------------------------------------------------------------
 --تلفن مسئول واحد فناور
  IF (@FieldName='ManagerTel')
begin
		DECLARE @NationalCode nvarchar(11)--كد ملي مسئول واحد فناور
		select @NationalCode= TDOO01H01_NationalCode from WSI_TDOO_PersonnelCooperation WITH(NOLOCK) where TDOO01H01_CompanyID=@CompanyID 
	    and TDOO01H01_CooperationType='Manager' and TDOO01H01_Status=0 and TDOO01H02_CheckResult<>'DisConfirmation' 
		
		  		
		SELECT  N'  نوع تلفن  ',N'  شماره تلفن  '
		 UNION
		SELECT N'ثابت',TDOO28H01_PhoneNo FROM dbo.WSI_TDOO_Phone_Compile With(Nolock)
		WHERE TDOO28H01_NationalCode = @NationalCode and (TDOO28H01_PhoneNo<>N'' and TDOO28H01_PhoneNo is not null)	
		 UNION
		SELECT N'فکس',TDOO28H01_FaxNo FROM dbo.WSI_TDOO_Phone_Compile With(Nolock)
		WHERE TDOO28H01_NationalCode = @NationalCode and (TDOO28H01_FaxNo<>N'' and TDOO28H01_FaxNo is not null)		
		 UNION
		SELECT N'همراه',TDOO28H01_MobileNo FROM dbo.WSI_TDOO_Phone_Compile With(Nolock)
		WHERE TDOO28H01_NationalCode = @NationalCode and (TDOO28H01_MobileNo<>N'' and TDOO28H01_MobileNo is not null)		
        
end   
--------------------------------------------------------------------------------------------------------------------------------
--نوع استقرار
IF (@FieldName='EstablishmentType')
  begin 
    select N' نوع استقرار'
    union
	select N'اراضي پارك علم و فناوري شيخ بهايي' from WSI_RERC_Park_Compile WITH(NOLOCK)where DocumentCode= @ParkDC and RERC06H01_LandPark=1
	union
	select N'ساختمان هاي چند مستاجره پارك علم و فناوري شيخ بهايي' from WSI_RERC_Park_Compile WITH(NOLOCK)where DocumentCode= @ParkDC and RERC06H01_LeasedPark=1
  end
-------------------------------------------------------------------------------------------------------------------------------
--نحوه استقرار
IF (@FieldName='EstablishmentMethod')
BEGIN
    DECLARE @Letter nvarchar(max)
    select @Letter=RERC06H01_EstablishmentMethod from WSI_RERC_Park_Compile WITH(NOLOCK)where DocumentCode= @ParkDC
	SELECT Name FROM YDigital_RadioButton WHERE GroupLetter='EstablishmentMethod'
	and Letter = @Letter
END

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- داوران تعیین شده جهت داوری واحد فناوری
	IF (@FieldName = 'Arbiters')
	--داوراني كه در گردش تعيين داور قبلي براي اين واحد فناوري تعيين شده اند و داوري را پذيرفته اند
	-- از فرم وابسته داوران واحد فناوري خوانده مي شود
	
		IF (select TOP 1 RelatedInCompile from Docs_Related_Records_Compile 
				where MasterDTC=@DTC_Arbiter and MasterDC= @ArbiterDetermination_MainDC
					and MasterInCompile=0 and RelatedDTC=@DTC_CompanyArbiter)=1	
						
		select  N'  نام داوران', N'  تلفن'
		UNION		
		select Name+ N' '+ family, MobileNumber from Users_PersonalInfo UP With(Nolock) 
		inner join WSI_RERC_CompanyArbiter_Compile CA on UP.UserCode=RERC34H01_ArbiterName
		inner join Docs_Related_Records_Compile on CA.DocumentCode=RelatedDC 
		where MasterDTC=@DTC_Arbiter and MasterDC=@ArbiterDetermination_MainDC and RelatedDTC=@DTC_CompanyArbiter
		and MasterInCompile=0 AND RelatedInCompile=1 and RERC34H01_ArbiterOpinion ='Accept' and Suspended=0
		
		ELSE
		
		select  N'  نام داوران', N'  تلفن'
		UNION		
		select Name+ N' '+ family, MobileNumber from Users_PersonalInfo UP With(Nolock) 
		inner join WSI_RERC_CompanyArbiter CA on UP.UserCode=RERC34H01_ArbiterName
		inner join Docs_Related_Records_Compile on CA.DocumentCode=RelatedDC 
		where MasterDTC=@DTC_Arbiter and MasterDC=@ArbiterDetermination_MainDC and RelatedDTC=@DTC_CompanyArbiter
		and MasterInCompile=0 AND RelatedInCompile=0 and RERC34H01_ArbiterOpinion ='Accept'
				 	
----------------------------------------------------------------------------------------------
--دکمه رادیویی مرحله سوم
	IF (@FieldName = 'Master')
		SELECT Name,Letter FROM YDigital_RadioButton WHERE GroupLetter='Confirmation' OR GroupLetter='Expert'
		
--دکمه رادیویی مرحله چهارم
	IF (@FieldName = 'Expert')
		SELECT Name,Letter FROM YDigital_RadioButton WHERE GroupLetter='Confirmation'
	
--دکمه رادیویی مرحله پنجم
	IF (@FieldName = 'ConclusionPerson')
		SELECT Name,Letter FROM YDigital_RadioButton WHERE GroupLetter='ConclusionPerson'

--دکمه رادیویی مرحله هشتم
	IF (@FieldName = 'Conclusion')
		SELECT Name,Letter,'1' as 'DEFNAL' FROM YDigital_RadioButton WHERE GroupLetter='Conclusion'
-------------------------------------------------------------------------------------------------------------------------------
IF (@FieldName='Arbiter')
   SELECT distinct UP.Name+' '+UP.Family,  UD.UserCode From Users_PersonalInfo UP 
	INNER JOIN wfi_UsersDashboards UD  ON UD.UserCode=UP.UserCode 
	 INNER JOIN wfi_WorkflowInstances WI ON UD.WFInstanceCode = WI.WFInstanceCode
	  INNER JOIN wfi_StateInstances SI ON SI.STInstanceCode = UD.STInstanceCode 
	   INNER JOIN wfd_WorkflowsStates WS ON WS.StateCode = SI.StateCode 
		  where WS.StateLetter IN('RERC17S01','RERC17S03') AND UD.Deleted = 0 and WI.PreviousWFInstanceCode= 
		   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
			inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
			 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
			   where CompileDC=@DocumentCode and DTC=@DTC_Seminar and WF.WorkflowLetter ='RERC14')
---------------------------------------------------------------------------------------------------------------------------
-- فرم تصاویر جلسه
IF (@FieldName='GRAV01')
 BEGIN
   DECLARE @DTC_InterviwePictures INT --تصاوير جلسه مصاحبه واحد فناور
     =(select DocumentTypeCode FROM Docs_Infos WITH(NOLOCK)WHERE DocumentTypeName='WSI_GRAV_InterviwePictures')

   DECLARE @MainDC_InterviwePictures INT --شماره رکورد اصلی تصاوير جلسه مصاحبه واحد فناور    
	=(select max(P.MainDC) from wfi_PoolInstances P
		inner join  wfi_WorkflowInstances WI With(Nolock) on  p.PoolInstanceCode=wi.PoolInstanceCode
		 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
		  where WF.WorkflowLetter ='GRAV01' and WI.PreviousWFInstanceCode IN 
		   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
			inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
			 inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
			   where CompileDC=@DocumentCode and DTC=@DTC_Seminar and WF.WorkflowLetter ='RERC14'))			   
    
   if @MainDC_InterviwePictures=-1
    select ''
    
   else
    select cast(@DTC_InterviwePictures as nvarchar(3)) + ',' + cast(@MainDC_InterviwePictures as nvarchar(3)) + ',0,' + 
      cast((select FormCode from dbo.Docs_Forms where FormLetter=N'GRAV01')as nvarchar(20))
  END			   		   
----------------------------------------------------------------------------------------------------------------------------
--نمایش جدولی نظرات مطرح شده در فرم های ارزیابی

IF (@FieldName='Collect')

  select N' ارزیابی کننده ',N' نظر درباره استقرار واحد در پارک ',N' توضیحات '
  
   union
   
  select RERC17H01_EvalutionerName,N'موافق',RERC17H01_Explain from WSI_RERC_ParkAdmissionAssessment_Compile 
   where RERC17H01_EstablishmentUnit='Agree' and RERC17H01_EvalutionerName<>N'' and RERC17H01_EvalutionerName is not null
    and DocumentCode IN --فرم هایی ارزیابی که از این گردش شروع شده اند
   (select CompileDC from wfi_PoolInstances P
     inner join  wfi_WorkflowInstances WI With(Nolock) on  p.PoolInstanceCode=wi.PoolInstanceCode
	  where WI.WFFinished=1 and DTC=@DTC_ParkAdmissionAssessment and WI.PreviousWFInstanceCode IN 
	   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
	    inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
	     inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
           where CompileDC=@DocumentCode and DTC=@DTC_Seminar and WF.WorkflowLetter ='RERC14'))
  union
  
  select RERC17H01_EvalutionerName,N'مخالف',RERC17H01_Explain from WSI_RERC_ParkAdmissionAssessment_Compile 
   where RERC17H01_EstablishmentUnit='Disagree' and RERC17H01_EvalutionerName<>N'' and RERC17H01_EvalutionerName is not null
   and DocumentCode IN --فرم هایی ارزیابی که از این گردش شروع شده اند
    (select CompileDC from wfi_PoolInstances P
     inner join  wfi_WorkflowInstances WI With(Nolock) on  p.PoolInstanceCode=wi.PoolInstanceCode
	  where WI.WFFinished=1 and DTC=@DTC_ParkAdmissionAssessment and WI.PreviousWFInstanceCode IN 
	   (select WFInstanceCode from wfi_WorkflowInstances WI with(Nolock)
	    inner join wfi_PoolInstances P on P.PoolInstanceCode= WI.PoolInstanceCode 
	     inner join wfd_Workflows AS WF ON WF.WorkflowCode=WI.WorkflowCode
           where CompileDC=@DocumentCode and DTC=@DTC_Seminar and WF.WorkflowLetter ='RERC14'))

----------------------------------------------------------------------------------------------------------------------------
--ميانگين نظرات موافق با استفاده از مزاياي ماده 9
IF (@FieldName='BenefitsOfArticle9')
  begin
    DECLARE @BenefitsOfArticle9 int--تعداد نظرات موافق با استفاده از مزاياي ماده 9

    select @BenefitsOfArticle9=count(*) from WSI_RERC_ParkAdmissionAssessment WITH(NOLOCK)where RERC17H01_BenefitsOfArticle9=1 
    and DocumentCode in(select AssessmentDC from @Temp)
    select (@BenefitsOfArticle9*100)/@AssessmentFormsNO
  end
-------------------------------------------------------------------------------------------------------------------------------   
--ميانگين نظرات موافق با استفاده از اعتبار معنوي شهرك
IF (@FieldName='TownMoralCredibility')
  begin
    DECLARE @TownMoralCredibility int--تعداد نظرات موافق با استفاده از اعتبار معنوي شهرك

    select @TownMoralCredibility=count(*) from WSI_RERC_ParkAdmissionAssessment WITH(NOLOCK)where RERC17H01_TownMoralCredibility=1 
    and DocumentCode in(select AssessmentDC from @Temp)
    --and RERC17H01_CompanyID=@CompanyID and RERC17H01_CurrentDate >= @SeminarDate
    select (@TownMoralCredibility*100)/@AssessmentFormsNO
  end
-------------------------------------------------------------------------------------------------------------------------------   
--ميانگين نظرات موافق با برخورداري  از خدمات ارزش افزوده
IF (@FieldName='ValueAddedServices')
  begin
    DECLARE @ValueAddedServices int--تعداد نظرات موافق با برخورداري  از خدمات ارزش افزوده

    select @ValueAddedServices=count(*) from WSI_RERC_ParkAdmissionAssessment WITH(NOLOCK)where RERC17H01_ValueAddedServices=1 
    and DocumentCode in(select AssessmentDC from @Temp)
    --and RERC17H01_CompanyID=@CompanyID and RERC17H01_CurrentDate >= @SeminarDate
    select (@ValueAddedServices*100)/@AssessmentFormsNO
  end
-------------------------------------------------------------------------------------------------------------------------------   
--ميانگين نظرات موافق با استفاده از هم افزايي واحدهاي فناوري
IF (@FieldName='SynergyOfTechnology')
  begin
    DECLARE @SynergyOfTechnology int--تعداد نظرات موافق با استفاده از هم افزايي واحدهاي فناوري

    select @SynergyOfTechnology=count(*) from WSI_RERC_ParkAdmissionAssessment WITH(NOLOCK)where RERC17H01_SynergyOfTechnology=1 
    and DocumentCode in(select AssessmentDC from @Temp)
    select (@SynergyOfTechnology*100)/@AssessmentFormsNO
  end
-------------------------------------------------------------------------------------------------------------------------------   
--ميانگين نظرات موافق با ساير انگيزه ها
IF (@FieldName='OtherIncentives')
  begin
    DECLARE @ActivityType int--تعداد نظرات موافق با ساير انگيزه ها

    select @ActivityType=count(*) from WSI_RERC_ParkAdmissionAssessment WITH(NOLOCK)where RERC17H01_OtherIncentives=1 
    and DocumentCode in(select AssessmentDC from @Temp)
    select (@ActivityType*100)/@AssessmentFormsNO
  end
-------------------------------------------------------------------------------------------------------------------------------   
--ميانگين نظرات موافق با استقرار واحد در شهرك
IF (@FieldName='Agrees')
  begin
    DECLARE @Agrees float--تعداد نظرات موافق با استقرار واحد در شهرك

    select @Agrees=count(*) from WSI_RERC_ParkAdmissionAssessment WITH(NOLOCK)where RERC17H01_EstablishmentUnit=N'Agree' 
    and DocumentCode in(select AssessmentDC from @Temp)
   
    select substring(cast(round((@Agrees*100)/@AssessmentFormsNO ,2) as nvarchar(10)), 1, 5)

  end   
-------------------------------------------------------------------------------------------------------------------------------   
--ميانگين نظرات مخالف با استقرار واحد در شهرك
IF (@FieldName='Opposite')
  begin
    DECLARE @Opposite float--تعداد نظرات مخالف با استقرار واحد در شهرك

    select @Opposite=count(*) from WSI_RERC_ParkAdmissionAssessment WITH(NOLOCK)where RERC17H01_EstablishmentUnit=N'Disagree' 
   and DocumentCode in(select AssessmentDC from @Temp)
   
    select substring(cast(round((@Opposite*100)/@AssessmentFormsNO ,2) as nvarchar(10)), 1, 5)
  end
----------------------------------------------------------------------------------------------
--تعداد نیروهای متخصص

	IF (@FieldName = 'Count')	
		
		SELECT N'  مدرک تحصیلی  ',N' تمام وقت ',N' نیمه وقت '
		
		UNION
		
		SELECT N' دکترا تخصصي',dbo.PersonelCount_CooperationStatus (@CompanyID,9,'Fulltime'),dbo.PersonelCount_CooperationStatus (@CompanyID,9,'Parttime')
		FROM WSI_TDOO_Personnel_Compile WITH(NOLOCK) inner join WSI_TDOO_PersonnelCooperation WITH(NOLOCK)
		on TDOO01H01_NationalCode=TDOO30H01_NationalCode
		where TDOO30H01_LastDegree=9 and TDOO01H01_CompanyID=@CompanyID and TDOO01H01_Status=0
		
		UNION	
			
		SELECT N' دکترا ',dbo.PersonelCount_CooperationStatus (@CompanyID,8,'Fulltime'),dbo.PersonelCount_CooperationStatus (@CompanyID,8,'Parttime')
		FROM WSI_TDOO_Personnel_Compile WITH(NOLOCK) inner join WSI_TDOO_PersonnelCooperation WITH(NOLOCK)
		on TDOO01H01_NationalCode=TDOO30H01_NationalCode
		where TDOO30H01_LastDegree=8 and TDOO01H01_CompanyID=@CompanyID and TDOO01H01_Status=0
			
		UNION
			
		SELECT N' کارشناسی ارشد ',dbo.PersonelCount_CooperationStatus (@CompanyID,7,'Fulltime'),dbo.PersonelCount_CooperationStatus (@CompanyID,7,'Parttime')
		FROM WSI_TDOO_Personnel_Compile WITH(NOLOCK) inner join WSI_TDOO_PersonnelCooperation WITH(NOLOCK)
		on TDOO01H01_NationalCode=TDOO30H01_NationalCode
		where TDOO30H01_LastDegree=7 and TDOO01H01_CompanyID=@CompanyID and TDOO01H01_Status=0
				
		UNION
			
		SELECT N' کارشناسی ',dbo.PersonelCount_CooperationStatus (@CompanyID,6,'Fulltime'),dbo.PersonelCount_CooperationStatus (@CompanyID,6,'Parttime')
		FROM WSI_TDOO_Personnel_Compile WITH(NOLOCK) inner join WSI_TDOO_PersonnelCooperation WITH(NOLOCK)
		on TDOO01H01_NationalCode=TDOO30H01_NationalCode
		where TDOO30H01_LastDegree=6 and TDOO01H01_CompanyID=@CompanyID and TDOO01H01_Status=0 
----------------------------------------------------------------------------------------------
--فناوری محوری
	IF @FieldName='IdeaTitle'
	
		SELECT RERC06H01_CoreTechnologyOrProduct from WSI_RERC_Park_Compile WITH(NOLOCK)where DocumentCode= @ParkDC
		
------------------------------------------------------------------------------------------------
----گردش مالی سالانه
	IF @FieldName='Turnover'
	
		SELECT TDOO26H01_AnnualTurnover FROM WSI_TDOO_Company WITH(NOLOCK)where DocumentCode= @CompanyID
------------------------------------------------------------------------------------------------
	IF @FieldName='PersonelInfo' --اطلاعات پرسنل 
	
	SELECT N' نام',N'نام خانوادگی',N'درصد سهام',N'نوع همکاری',N'وضعیت همکاری',N' رشته تحصيلي',N'مدرك تحصيلي و دانشگاه محل تحصيل',N'مشاهده فرم'
	 UNION
	SELECT TDOO01H01_Name,TDOO01H01_Family,cast(TDOO01H01_Shares as nvarchar(10))
	 ,TDOO01H01_CooperationTypeShow,TDOO01H01_CooperationStatusShow,TDOO01H01_LastField,TDOO01H01_LastDegree,
	 '<a target = "_ " href="http://212.50.246.101/DL/Data%20Entry/WorkflowDataEntry/CreateDocument.aspx?DataEntryTypeCode=4&DTC='+CAST(@DTC_PersonnelCooperation AS NVARCHAR(10))+'&DC='+cast(DocumentCode as nvarchar(max))+N'&RandomParam=0.17220514785126756">مشاهده فرم</a>'
     FROM WSI_TDOO_PersonnelCooperation 
       WHERE TDOO01H01_CompanyID=@CompanyID AND TDOO01H01_Status=0
	     and TDOO01H02_CheckResult<>'DisConfirmation' 	   	   
	

	   
END

