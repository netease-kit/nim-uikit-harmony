import abilityTest from './Ability.test';
import localUnitTest from './LocalUnit.test';
import contactVerifyUnreadTest from './ContactVerifyUnread.test';
import teamVerifyViewModelTest from './TeamVerifyViewModel.test';
import teamProfilePageTest from './TeamProfilePage.test';
import contactModelTest from './ContactModel.test';
import teamVerifyInfoBeanTest from './TeamVerifyInfoBean.test';
import contactLogicTest from './ContactLogic.test';

export default function testsuite() {
  abilityTest(); localUnitTest(); contactVerifyUnreadTest();
  teamVerifyViewModelTest(); teamProfilePageTest(); contactModelTest();
  teamVerifyInfoBeanTest(); contactLogicTest();
}