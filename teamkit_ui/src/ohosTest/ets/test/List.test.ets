import abilityTest from './Ability.test';
import localUnitTest from './LocalUnit.test';
import teamJoinManageTest from './TeamJoinManage.test';
import teamMemberListViewModelTest from './TeamMemberListViewModel.test';
import teamMemberSelectorViewModelTest from './TeamMemberSelectorViewModel.test';
import teamManagerListViewModelTest from './TeamManagerListViewModel.test';

export default function testsuite() {
  abilityTest();
  localUnitTest();
  teamJoinManageTest();
  teamMemberListViewModelTest();
  teamMemberSelectorViewModelTest();
  teamManagerListViewModelTest();
}
